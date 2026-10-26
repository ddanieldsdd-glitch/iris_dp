import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/export_file_saver.dart';
import '../camera_plan_constants.dart';
import '../camera_plan_element_model.dart';
import '../light/ambient.dart';
import '../light/plan_light.dart';
import '../plan_cad_export.dart';
import '../plan_piece_controls.dart';
import 'light_floor.dart';
import 'plan_rig.dart';
import 'plan_scene3d.dart';
import '../../unreal_link/unreal_link.dart';
import '../../unreal_link/unreal_link_button.dart';
import '../../unreal_link/unreal_asset_tile.dart';
import '../../unreal_link/unreal_render_view.dart';
import '../../unreal_link/unreal_return.dart';
import '../../unreal_link/unreal_stage_payload.dart';
import 'scan_store.dart';
import 'rig_report.dart';

/// Capas del 3D que se pueden ocultar, con su nombre en el visor.
const _layers = <(String, String)>[
  ('walls', 'Paredes'),
  ('glass', 'Vidrio'),
  ('drapes', 'Telas'),
  ('pillars', 'Pilares'),
  ('rig', 'Truss, motores y torres'),
  ('fixtures', 'Focos'),
  ('people', 'Personas y cámaras'),
];

/// La planta en 3D: three.js en un WebView, empaquetado en la app para que
/// funcione sin red (`assets/viewer3d/`). Recibe la escena resuelta
/// ([PlanScene3d]) cada vez que la planta cambia y avisa de lo que se toca
/// en el 3D para seleccionarlo también en la planta.
///
/// En panel (junto a la planta) la barra es compacta; a pantalla entera
/// ([full]) lleva un lateral con todas las opciones y el resumen.
class Plan3dView extends StatefulWidget {
  final List<PlanElement> elements;
  final double metersPerUnit;
  final String? name;
  final PlanElement? selected;
  final ValueChanged<PlanElement?>? onSelect;

  /// Sol y cielo del esquema de luz, para el sol del 3D y la luz del suelo.
  final PlanAmbient? ambient;

  /// Algo nuevo creado desde el 3D (un escaneo importado): la planta lo da
  /// de alta.
  final Future<void> Function(PlanElement)? onAdd;

  /// Algo cambiado desde el 3D (movido, apuntado, retocado en el lateral):
  /// la planta lo guarda. Sin él, el 3D solo se mira.
  final Future<void> Function(PlanElement)? onChanged;

  /// Pantalla entera, con el lateral de opciones.
  final bool full;

  /// Panel: pasar a pantalla entera.
  final VoidCallback? onExpand;

  /// Panel: cerrar.
  final VoidCallback? onClose;

  /// El mundo de Unreal de esta planta (su set o su localización).
  final UnrealWorld? unrealWorld;

  /// Guarda una captura RTX de Unreal en el storyboard del plano; sin él
  /// (planta de set o de localización) no se captura.
  final UnrealCaptureSink? onUnrealCapture;

  /// «Abrir en Unreal» del proyecto de esta planta.
  final Future<void> Function()? onOpenUnreal;

  const Plan3dView({
    super.key,
    required this.elements,
    required this.metersPerUnit,
    this.name,
    this.selected,
    this.onSelect,
    this.ambient,
    this.onChanged,
    this.onAdd,
    this.full = false,
    this.onExpand,
    this.onClose,
    this.unrealWorld,
    this.onUnrealCapture,
    this.onOpenUnreal,
  });

  static const asset = 'assets/viewer3d/index.html';

  @override
  State<Plan3dView> createState() => _Plan3dViewState();
}

class _Plan3dViewState extends State<Plan3dView> {
  InAppWebViewController? _web;
  bool _ready = false;
  String? _sent;
  Map<String, dynamic>? _scene;
  Timer? _debounce;
  String _view = 'iso';
  bool _cones = true;
  bool _roof = true;
  bool _ortho = false;
  final _show = {for (final (k, _) in _layers) k: true};
  late PlanElement? _selected = widget.selected;
  String? _status;

  /// La luz calculada pintada en el suelo.
  bool _floor = false;
  int _floorRun = 0;
  bool _floorBusy = false;

  bool _measuring = false;
  String? _measure;

  /// Última medida, en metros: sirve para calibrar un escaneo.
  double? _measuredM;
  final _realLength = TextEditingController();

  /// Cambios que llegan de Unreal (IRIS Stage Link).
  StreamSubscription<List<UnrealEdit>>? _fromUnreal;

  @override
  void initState() {
    super.initState();
    _realLength.addListener(() => setState(() {}));
    _fromUnreal = UnrealLink.instance.edits.listen(_applyFromUnreal);
    _schedule();
  }

  @override
  void didUpdateWidget(Plan3dView old) {
    super.didUpdateWidget(old);
    _schedule();
    if (old.selected != widget.selected) {
      _selected = widget.selected;
      _pushSelection();
    }
  }

  @override
  void dispose() {
    _fromUnreal?.cancel();
    _debounce?.cancel();
    _realLength.dispose();
    super.dispose();
  }

  /// La planta cambia a menudo mientras se arrastra: se manda al 3D como
  /// mucho cada 150 ms y solo si ha cambiado.
  void _schedule() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 150), _push);
  }

  Future<void> _push() async {
    if (!mounted) return;
    final scene = PlanScene3d.build(
      widget.elements,
      metersPerUnit: widget.metersPerUnit,
      name: widget.name,
      ambient: widget.ambient,
    );
    // Unreal recibe la misma escena, esté o no listo el visor.
    UnrealLink.instance.offer(scene, world: widget.unrealWorld);
    final web = _web;
    if (!_ready || web == null) return;
    final json = jsonEncode(scene);
    if (json == _sent) return;
    _sent = json;
    setState(() => _scene = scene);
    await web.evaluateJavascript(source: 'iris.load($json);');
    await _pushSelection();
    if (_floor) unawaited(_pushFloor());
  }

  /// Calcula la luz en el suelo aparte y la manda; si entretanto la planta
  /// ha cambiado, se descarta y vale la siguiente.
  Future<void> _pushFloor() async {
    final run = ++_floorRun;
    if (!_floor) {
      await _call('iris.floor(null);');
      return;
    }
    setState(() => _floorBusy = true);
    final floor = await LightFloor.build(
      widget.elements,
      metersPerUnit: widget.metersPerUnit,
      ambient: widget.ambient,
    );
    if (!mounted || run != _floorRun) return;
    setState(() => _floorBusy = false);
    await _call('iris.floor(${jsonEncode(floor)});');
  }

  Future<void> _pushSelection() async {
    final web = _web;
    if (!_ready || web == null) return;
    final index = _selected == null ? -1 : widget.elements.indexOf(_selected!);
    final id = index < 0
        ? null
        : PlanScene3d.idOf(widget.elements[index], index);
    await web.evaluateJavascript(source: 'iris.select(${jsonEncode(id)});');
  }

  Future<void> _call(String js) async => _web?.evaluateJavascript(source: js);

  void _setView(String v) {
    setState(() => _view = v);
    _call('iris.view(${jsonEncode(v)});');
  }

  void _set(Map<String, Object> options) =>
      _call('iris.set(${jsonEncode(options)});');

  dynamic _onMessage(List<dynamic> args) {
    final message = args.isEmpty ? null : args.first;
    if (message is! Map) return null;
    switch (message['type']) {
      case 'ready':
        _ready = true;
        _sent = null;
        final bg = context.palette.background;
        final hex = (bg.toARGB32() & 0xFFFFFF)
            .toRadixString(16)
            .padLeft(6, '0');
        _set({
          'bg': '#$hex',
          'cones': _cones,
          'roof': _roof,
          'ortho': _ortho,
          'show': _show,
        });
        _push();
      case 'select':
        final id = message['id'];
        PlanElement? hit;
        for (final (i, el) in widget.elements.indexed) {
          if (PlanScene3d.idOf(el, i) == id) hit = el;
        }
        if (mounted) setState(() => _selected = hit);
        widget.onSelect?.call(hit);
      case 'measure':
        String m(Object? v) =>
            '${((v as num?) ?? 0).toStringAsFixed(2).replaceAll('.', ',')} m';
        if (mounted) {
          setState(() {
            _measuredM = (message['d'] as num?)?.toDouble();
            _measure =
                '${m(message['d'])} · en planta ${m(message['dxy'])} · '
                'desnivel ${m(message['dz'])}';
          });
        }
      case 'scanData':
        // El visor pide los bytes de un escaneo: se le devuelven en base64.
        return ScanStore.bytesOf(
          message['file'] as String,
        ).then((bytes) => bytes == null ? null : base64Encode(bytes));
      case 'scanError':
        if (mounted) {
          setState(() => _status = 'Escaneo: ${message['message']}');
        }
      case 'move' || 'aim':
        _applyFrom3d(message);
      case 'view':
        if (mounted) setState(() => _view = message['view'] as String);
      case 'loaded':
        final lit = message['lit'], total = message['fixtures'];
        if (mounted && total is num && lit is num) {
          setState(
            () => _status = total > lit
                ? '$lit de $total focos con luz real'
                : null,
          );
        }
    }
    return null;
  }

  PlanElement? _byId(Object? id) {
    for (final (i, el) in widget.elements.indexed) {
      if (PlanScene3d.idOf(el, i) == id) return el;
    }
    return null;
  }

  /// Lo arrastrado en el 3D pasa a la planta: se mueve o se apunta el
  /// elemento y la planta lo guarda (y, si es una luz, la cuelga del truss
  /// que tenga cerca).
  Future<void> _applyFrom3d(Map message) async {
    final save = widget.onChanged;
    final el = _byId(message['id']);
    if (save == null || el == null) return;
    double n(String k) => (message[k] as num?)?.toDouble() ?? 0;
    final mpu = widget.metersPerUnit;
    if (message['type'] == 'move') {
      if (!PlanScene3d.moveBy(el, n('dx'), n('dy'), widget.elements, mpu)) {
        return;
      }
    } else if (el.type == ElementType.light) {
      PlanScene3d.aimAt(el, n('x'), n('y'), n('z'), mpu);
    } else {
      return;
    }
    await save(el);
    if (!mounted) return;
    setState(() => _selected = el);
    _schedule();
  }

  /// Lo que se ha movido, regulado o recoloreado en Unreal vuelve a la
  /// planta y se guarda, como si se hubiera hecho en este 3D.
  Future<void> _applyFromUnreal(List<UnrealEdit> edits) async {
    final save = widget.onChanged;
    if (save == null || !mounted) return;
    for (final edit in edits) {
      final el = _byId(edit.id);
      if (el == null || !edit.claim()) continue;
      if (UnrealReturn.apply(el, edit, widget.elements, widget.metersPerUnit)) {
        await save(el);
      }
    }
    if (mounted) _preview();
  }

  /// Retoque desde el lateral: repinta mientras se arrastra y guarda al
  /// soltar.
  void _preview() {
    setState(() {});
    _schedule();
  }

  Future<void> _update() async {
    final el = _selected, save = widget.onChanged;
    if (el == null || save == null) return;
    await save(el);
    if (mounted) _preview();
  }

  /// Importa un escaneo (Polycam, Luma AI…): se copia a la carpeta de la
  /// app y se coloca en el centro de lo que hay.
  Future<void> _importScan() async {
    final add = widget.onAdd;
    if (add == null) return;
    final picked = await FilePicker.platform.pickFiles(
      dialogTitle: 'Importar un escaneo',
      type: FileType.custom,
      allowedExtensions: PlanScan.formats,
    );
    final path = picked?.files.single.path;
    if (path == null) return;
    final file = await ScanStore.import(path);
    var centre = Offset.zero;
    if (widget.elements.isNotEmpty) {
      for (final el in widget.elements) {
        centre += el.position;
      }
      centre /= widget.elements.length.toDouble();
    }
    final scan = PlanScan.create(
      centre,
      file: file,
      format: file.split('.').last,
      name: path.split(Platform.pathSeparator).last,
    );
    await add(scan);
    if (!mounted) return;
    setState(() => _selected = scan);
    _schedule();
  }

  List<Widget> _scanSection(AppPalette palette) {
    final el = _selected;
    final caption = AppTypography.caption(
      palette,
    ).copyWith(color: palette.textTertiary);
    if (el == null || !PlanScan.isScan(el)) {
      return [
        if (widget.onAdd != null)
          OutlinedButton.icon(
            icon: const Icon(Icons.view_in_ar, size: 16),
            label: const Text('Importar escaneo (GLB, OBJ, PLY)'),
            onPressed: _importScan,
          ),
        Text(
          'De Polycam o Luma AI. Luego tócalo para colocarlo, girarlo y '
          'ponerlo a escala.',
          style: caption,
        ),
      ];
    }
    Widget slider(
      String label,
      String value,
      double current,
      double min,
      double max,
      ValueChanged<double> set,
    ) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(label, style: AppTypography.caption(palette))),
            Text(value, style: AppTypography.mono(palette)),
          ],
        ),
        Slider(
          value: current.clamp(min, max),
          min: min,
          max: max,
          onChanged: (v) {
            set(v);
            _preview();
          },
          onChangeEnd: (_) => _update(),
        ),
      ],
    );
    final real = double.tryParse(_realLength.text.replaceAll(',', '.'));
    return [
      Text(
        el.props[PlanScan.nameKey] as String? ?? 'Escaneo',
        style: AppTypography.bodyMedium(palette),
      ),
      slider(
        'Giro',
        '${el.rotation.round()}°',
        el.rotation,
        0,
        359,
        (v) => el.rotation = v.roundToDouble(),
      ),
      slider(
        'Subir o bajar (su suelo al de la planta)',
        '${PlanScan.offsetZ(el).toStringAsFixed(2)} m',
        PlanScan.offsetZ(el),
        -5,
        5,
        (v) => el.props[PlanScan.offsetKey] = (v * 100).round() / 100,
      ),
      slider(
        'Escala',
        PlanScan.scale(el).toStringAsFixed(3),
        PlanScan.scale(el),
        0.01,
        10,
        (v) => el.props[PlanScan.scaleKey] = v,
      ),
      Text(
        'A escala con una medida: activa «Medir», toca los dos extremos de '
        'algo que conozcas (una puerta, una baldosa) y escribe lo que mide.',
        style: caption,
      ),
      Row(
        children: [
          Expanded(
            child: TextField(
              controller: _realLength,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                isDense: true,
                labelText: 'Mide de verdad (m)',
                helperText: _measuredM == null
                    ? 'Aún no hay medida'
                    : 'En el escaneo: ${_measuredM!.toStringAsFixed(2)} m',
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          FilledButton(
            onPressed: _measuredM == null || real == null || real <= 0
                ? null
                : () {
                    PlanScan.calibrate(el, _measuredM!, real);
                    _measuredM = null;
                    _realLength.clear();
                    _update();
                  },
            child: const Text('Calibrar'),
          ),
        ],
      ),
    ];
  }

  /// MVR con las luces y, dentro, la nave y su estructura en glTF.
  Future<void> _exportMvr() async {
    final web = _web;
    if (web == null || !_ready) return;
    final result = await web.callAsyncJavaScript(
      functionBody: 'return await iris.exportGlb({structure: true});',
    );
    final b64 = result?.value;
    final glb = b64 is String && b64.isNotEmpty ? base64Decode(b64) : null;
    final base = (widget.name ?? 'planta').replaceAll(RegExp(r'[^\w\- ]'), '');
    final bytes = PlanCadExport.planMvr(
      widget.elements,
      widget.metersPerUnit,
      layerName: base,
      environmentGlb: glb,
    );
    await ExportFileSaver.saveBytes(
      bytes: bytes,
      dialogTitle: 'Guardar el MVR',
      fileName: '$base luces',
      extension: 'mvr',
    );
  }

  /// Guarda lo que se ve en un glTF binario, para Unreal o cualquier
  /// programa 3D.
  Future<void> _exportGlb() async {
    final web = _web;
    if (web == null || !_ready) return;
    final result = await web.callAsyncJavaScript(
      functionBody: 'return await iris.exportGlb();',
    );
    final b64 = result?.value;
    if (b64 is! String || b64.isEmpty) return;
    final bytes = base64Decode(b64);
    final name =
        '${(widget.name ?? 'planta').replaceAll(RegExp(r'[^\w\- ]'), '')}.glb';
    final path = await FilePicker.platform.saveFile(
      dialogTitle: 'Exportar el 3D',
      fileName: name,
      bytes: bytes,
    );
    // En el Mac el diálogo solo da la ruta: el archivo se escribe aquí.
    if (path != null && !Platform.isIOS && !Platform.isAndroid) {
      await File(path).writeAsBytes(bytes);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final viewer = Stack(
      children: [
        InAppWebView(
          initialFile: Plan3dView.asset,
          initialSettings: InAppWebViewSettings(
            isInspectable: kDebugMode,
            transparentBackground: false,
            disableContextMenu: true,
            supportZoom: false,
            allowFileAccessFromFileURLs: true,
            allowUniversalAccessFromFileURLs: true,
          ),
          onWebViewCreated: (controller) {
            _web = controller;
            controller.addJavaScriptHandler(
              handlerName: 'iris',
              callback: _onMessage,
            );
          },
        ),
        if (_status != null)
          Positioned(
            left: AppSpacing.sm,
            bottom: AppSpacing.sm,
            child: Text(
              _status!,
              style: AppTypography.caption(
                palette,
              ).copyWith(color: palette.textTertiary),
            ),
          ),
      ],
    );
    if (widget.full) {
      return Material(
        color: palette.surface,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: viewer),
            VerticalDivider(width: 1, color: palette.divider),
            SizedBox(width: 300, child: _sidebar(palette)),
          ],
        ),
      );
    }
    return Material(
      color: palette.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _compactBar(palette),
          Divider(height: 1, color: palette.divider),
          Expanded(child: viewer),
        ],
      ),
    );
  }

  // ── Panel junto a la planta: lo justo, sin desbordar ─────────────────────

  Widget _compactBar(AppPalette palette) => Padding(
    padding: const EdgeInsets.symmetric(
      horizontal: AppSpacing.xs,
      vertical: AppSpacing.xs,
    ),
    child: Row(
      children: [
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: _viewButtons(compact: true),
          ),
        ),
        UnrealLinkButton(
          link: UnrealLink.instance,
          onOpenUnreal: widget.onOpenUnreal,
        ),
        ListenableBuilder(
          listenable: UnrealLink.instance,
          builder: (context, _) => UnrealLink.instance.isOn
              ? IconButton(
                  tooltip: 'Render RTX: ver Unreal aquí',
                  icon: Icon(
                    Icons.live_tv_outlined,
                    size: 18,
                    color: palette.textSecondary,
                  ),
                  onPressed: _openRender,
                )
              : const SizedBox.shrink(),
        ),
        PopupMenuButton<String>(
          tooltip: 'Qué se ve',
          icon: Icon(
            Icons.layers_outlined,
            size: 18,
            color: palette.textSecondary,
          ),
          itemBuilder: (_) => [
            CheckedPopupMenuItem(
              value: 'cones',
              checked: _cones,
              child: const Text('Conos de luz'),
            ),
            CheckedPopupMenuItem(
              value: 'roof',
              checked: _roof,
              child: const Text('Cubierta'),
            ),
            CheckedPopupMenuItem(
              value: 'ortho',
              checked: _ortho,
              child: const Text('Ortográfica'),
            ),
            CheckedPopupMenuItem(
              value: 'floor',
              checked: _floor,
              child: const Text('Luz calculada en el suelo'),
            ),
            CheckedPopupMenuItem(
              value: 'measure',
              checked: _measuring,
              child: const Text('Medir (dos toques)'),
            ),
            for (final c in _cameras)
              PopupMenuItem(
                value: 'cam:${c.$1}',
                child: Text('Ver por la cámara ${c.$2}'),
              ),
            const PopupMenuDivider(),
            for (final (key, label) in _layers)
              CheckedPopupMenuItem(
                value: key,
                checked: _show[key]!,
                child: Text(label),
              ),
          ],
          onSelected: (v) => v.startsWith('cam:') ? _setView(v) : _toggle(v),
        ),
        if (RigReport.warnings(widget.elements, widget.metersPerUnit)
            case final list when list.isNotEmpty)
          IconButton(
            tooltip: [for (final w in list) w.text].join('\n'),
            icon: Icon(
              Icons.warning_amber,
              size: 18,
              color: list.any((w) => w.serious)
                  ? palette.error
                  : palette.warning,
            ),
            onPressed: widget.onExpand,
          ),
        if (widget.onExpand != null)
          IconButton(
            tooltip: 'Abrir el 3D a pantalla entera',
            icon: Icon(
              Icons.open_in_full,
              size: 18,
              color: palette.textSecondary,
            ),
            onPressed: widget.onExpand,
          ),
        if (widget.onClose != null)
          IconButton(
            tooltip: 'Cerrar el 3D',
            icon: const Icon(Icons.close, size: 18),
            onPressed: widget.onClose,
          ),
      ],
    ),
  );

  /// Cámaras de la escena: id, nombre y objetivo.
  List<(String, String, String?)> get _cameras => [
    for (final c in (_scene?['cameras'] as List? ?? const []).cast<Map>())
      (c['id'] as String, c['name'] as String, c['lens'] as String?),
  ];

  void _toggle(String key) {
    setState(() {
      switch (key) {
        case 'cones':
          _cones = !_cones;
          _set({'cones': _cones});
        case 'roof':
          _roof = !_roof;
          _set({'roof': _roof});
        case 'ortho':
          _ortho = !_ortho;
          _set({'ortho': _ortho});
        case 'floor':
          _floor = !_floor;
          _pushFloor();
        case 'measure':
          _measuring = !_measuring;
          _measure = null;
          _set({'measure': _measuring});
        default:
          _show[key] = !_show[key]!;
          _set({
            'show': {key: _show[key]!},
          });
      }
    });
  }

  Widget _viewButtons({required bool compact, bool all = false}) {
    final views = [
      ('top', 'Arriba'),
      ('front', 'Frente'),
      ('right', 'Lado'),
      if (all) ('back', 'Fondo'),
      if (all) ('left', 'Otro lado'),
      ('iso', 'Iso'),
    ];
    return SegmentedButton<String>(
      showSelectedIcon: false,
      style: ButtonStyle(
        visualDensity: compact
            ? const VisualDensity(horizontal: -3, vertical: -3)
            : VisualDensity.compact,
      ),
      segments: [
        for (final (v, label) in views)
          ButtonSegment(value: v, label: Text(label)),
      ],
      selected: {views.any((e) => e.$1 == _view) ? _view : 'iso'},
      onSelectionChanged: (v) => _setView(v.first),
    );
  }

  // ── Pantalla entera: todas las opciones ─────────────────────────────────

  Widget _sidebar(AppPalette palette) {
    Widget header(String text) => Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md, bottom: AppSpacing.xs),
      child: Text(text.toUpperCase(), style: AppTypography.label(palette)),
    );
    Widget toggle(String label, bool on, VoidCallback onTap) => SwitchListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      title: Text(label),
      value: on,
      onChanged: (_) => onTap(),
    );
    final views = <(String, String, IconData)>[
      ('top', 'Arriba', Icons.vertical_align_bottom),
      ('front', 'Frente', Icons.crop_portrait),
      ('right', 'Lado', Icons.arrow_back),
      ('left', 'Otro lado', Icons.arrow_forward),
      ('back', 'Fondo', Icons.flip_to_back),
      ('iso', 'Iso', Icons.view_in_ar_outlined),
    ];
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        0,
        AppSpacing.md,
        AppSpacing.md,
      ),
      children: [
        header('Vista'),
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 6,
          crossAxisSpacing: 6,
          childAspectRatio: 1.6,
          children: [
            for (final (v, label, icon) in views)
              _ViewTile(
                label: label,
                icon: icon,
                selected: _view == v,
                onTap: () => _setView(v),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        SegmentedButton<bool>(
          showSelectedIcon: false,
          style: const ButtonStyle(visualDensity: VisualDensity.compact),
          segments: const [
            ButtonSegment(value: false, label: Text('Perspectiva')),
            ButtonSegment(value: true, label: Text('Ortográfica')),
          ],
          selected: {_ortho},
          onSelectionChanged: (v) {
            if (v.first != _ortho) _toggle('ortho');
          },
        ),
        Text(
          'Arrastra para girar, pellizca o rueda para acercar, dos dedos '
          'para desplazar. El cubo de la esquina también cambia la vista.',
          style: AppTypography.caption(
            palette,
          ).copyWith(color: palette.textTertiary),
        ),
        if (_cameras.isNotEmpty) ...[
          header('Por la cámara'),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              for (final (id, name, lens) in _cameras)
                ChoiceChip(
                  label: Text(lens == null ? name : '$name · $lens'),
                  selected: _view == 'cam:$id',
                  onSelected: (_) => _setView('cam:$id'),
                ),
            ],
          ),
          Text(
            'Desde la altura del objetivo y con su focal: el marco es lo que '
            'entra en un 16:9.',
            style: AppTypography.caption(
              palette,
            ).copyWith(color: palette.textTertiary),
          ),
        ],
        header('Medir'),
        toggle('Medir con dos toques', _measuring, () => _toggle('measure')),
        if (_measuring)
          Text(
            _measure ?? 'Toca un punto y luego otro: suelo, truss, pared…',
            style: _measure == null
                ? AppTypography.caption(
                    palette,
                  ).copyWith(color: palette.textTertiary)
                : AppTypography.mono(palette),
          ),
        header('Qué se ve'),
        toggle('Cubierta', _roof, () => _toggle('roof')),
        toggle('Conos de luz', _cones, () => _toggle('cones')),
        toggle(
          _floorBusy ? 'Luz en el suelo (calculando…)' : 'Luz en el suelo',
          _floor,
          () => _toggle('floor'),
        ),
        for (final (key, label) in _layers)
          toggle(label, _show[key]!, () => _toggle(key)),
        header('En la escena'),
        ..._summary(palette),
        ..._warnings(palette),
        header('Selección'),
        Text(
          _selected == null
              ? 'Toca algo en el 3D para seleccionarlo también en la planta.'
              : _selected!.displayLabel,
          style: AppTypography.bodyMedium(palette),
        ),
        if (_selected != null && widget.onChanged != null) ...[
          Text(
            _selected!.type == ElementType.light
                ? 'Arrástralo para moverlo; el asa naranja cambia adónde '
                      'apunta. Cerca de un truss se cuelga de él.'
                : 'Arrástralo para moverlo por el suelo.',
            style: AppTypography.caption(
              palette,
            ).copyWith(color: palette.textTertiary),
          ),
          const SizedBox(height: AppSpacing.sm),
          if (_selected!.type == ElementType.light)
            _LightControls(
              element: _selected!,
              onPreview: _preview,
              onUpdate: _update,
            )
          else if (PlanPieceControls.appliesTo(_selected!))
            PlanPieceControls(
              element: _selected!,
              metersPerUnit: widget.metersPerUnit,
              onPreview: _preview,
              onUpdate: _update,
            ),
          if (_selected!.type == ElementType.prop &&
              PlanScene3d.furniture.contains(_selected!.propType))
            UnrealAssetTile(
              element: _selected!,
              link: UnrealLink.instance,
              onChanged: _update,
            ),
        ],
        header('Escaneos'),
        ..._scanSection(palette),
        header('Exportar'),
        OutlinedButton.icon(
          icon: const Icon(Icons.ios_share, size: 16),
          label: const Text('glTF (.glb) para Unreal'),
          onPressed: _exportGlb,
        ),
        const SizedBox(height: AppSpacing.xs),
        OutlinedButton.icon(
          icon: const Icon(Icons.lightbulb_outline, size: 16),
          label: const Text('MVR con la nave y la estructura'),
          onPressed: _exportMvr,
        ),
        header('Unreal en vivo'),
        ListenableBuilder(
          listenable: UnrealLink.instance,
          builder: (context, _) => OutlinedButton.icon(
            icon: const Icon(Icons.cast_connected_outlined, size: 16),
            label: Text(
              UnrealLink.instance.isOn
                  ? 'Conectado con Unreal'
                  : 'Conectar con Unreal',
            ),
            onPressed: () => showUnrealLinkDialog(
              context,
              UnrealLink.instance,
              onOpenUnreal: widget.onOpenUnreal,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        OutlinedButton.icon(
          icon: const Icon(Icons.live_tv_outlined, size: 16),
          label: const Text('Render RTX: ver Unreal aquí'),
          onPressed: _openRender,
        ),
        Text(
          'Lo que muevas, regules o cambies de color en Unreal vuelve a la '
          'planta.',
          style: AppTypography.caption(
            palette,
          ).copyWith(color: palette.textTertiary),
        ),
      ],
    );
  }

  void _openRender() => UnrealRenderScreen.open(
    context,
    cameras: [for (final (id, name, _) in _cameras) (id, name)],
    onCapture: widget.onUnrealCapture,
  );

  /// Avisos de rigging; tocar uno selecciona lo que lo provoca.
  List<Widget> _warnings(AppPalette palette) {
    final list = RigReport.warnings(widget.elements, widget.metersPerUnit);
    if (list.isEmpty) return const [];
    return [
      const SizedBox(height: AppSpacing.sm),
      for (final w in list)
        InkWell(
          onTap: () {
            setState(() => _selected = w.element);
            _pushSelection();
            widget.onSelect?.call(w.element);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  w.serious ? Icons.error_outline : Icons.warning_amber,
                  size: 16,
                  color: w.serious ? palette.error : palette.warning,
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(w.text, style: AppTypography.caption(palette)),
                ),
              ],
            ),
          ),
        ),
    ];
  }

  List<Widget> _summary(AppPalette palette) {
    final s = _scene;
    if (s == null) {
      return [Text('Cargando…', style: AppTypography.caption(palette))];
    }
    List<Map> list(String k) => (s[k] as List? ?? const []).cast<Map>();
    final fixtures = list('fixtures');
    final watts = fixtures.fold<double>(
      0,
      (a, f) => a + ((f['watts'] as num?)?.toDouble() ?? 0),
    );
    var trussM = 0.0;
    for (final t in list('trusses')) {
      final a = (t['from'] as List).cast<num>(),
          b = (t['to'] as List).cast<num>();
      trussM += math.sqrt(math.pow(b[0] - a[0], 2) + math.pow(b[1] - a[1], 2));
    }
    final rig = list('rigging');
    final motors = rig.where((r) => r['type'] == 'motor').length;
    final towers = rig.length - motors;
    final rows = <(String, String)>[
      (
        'Focos',
        '${fixtures.length}'
            '${watts > 0 ? ' · ${(watts / 1000).toStringAsFixed(1)} kW' : ''}',
      ),
      if (trussM > 0) ('Truss', '${trussM.toStringAsFixed(1)} m'),
      if (motors > 0) ('Motores', '$motors'),
      if (towers > 0) ('Ground support', '$towers'),
      ('Paredes', '${list('walls').length}'),
      if (list('drapes').isNotEmpty) ('Telas', '${list('drapes').length}'),
      if (list('pillars').isNotEmpty) ('Pilares', '${list('pillars').length}'),
    ];
    return [
      for (final (label, value) in rows)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            children: [
              Expanded(
                child: Text(label, style: AppTypography.caption(palette)),
              ),
              Text(value, style: AppTypography.mono(palette)),
            ],
          ),
        ),
    ];
  }
}

/// Lo justo de una luz para retocarla en el 3D: si cuelga, a qué altura,
/// hacia dónde mira y cuánto se inclina.
class _LightControls extends StatelessWidget {
  final PlanElement element;
  final VoidCallback onPreview;
  final VoidCallback onUpdate;

  const _LightControls({
    required this.element,
    required this.onPreview,
    required this.onUpdate,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final el = element;
    final overhead = PlanLight.isOverhead(el);
    final onTruss = el.props['rig'] != null;

    Widget slider(
      String label,
      String value, {
      required double current,
      required double min,
      required double max,
      required ValueChanged<double> onChanged,
    }) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(label, style: AppTypography.caption(palette))),
            Text(value, style: AppTypography.mono(palette)),
          ],
        ),
        Slider(
          value: current.clamp(min, max),
          min: min,
          max: max,
          onChanged: (v) {
            onChanged(v);
            onPreview();
          },
          onChangeEnd: (_) => onUpdate(),
        ),
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SegmentedButton<bool>(
          showSelectedIcon: false,
          style: const ButtonStyle(visualDensity: VisualDensity.compact),
          segments: const [
            ButtonSegment(value: false, label: Text('Trípode')),
            ButtonSegment(value: true, label: Text('Colgada')),
          ],
          selected: {overhead},
          onSelectionChanged: (v) {
            if (v.first) {
              el.props[PlanLight.mountKey] = PlanLight.mountCeiling;
            } else {
              el.props
                ..remove(PlanLight.mountKey)
                ..remove('rig');
            }
            onUpdate();
          },
        ),
        if (!onTruss)
          slider(
            'Altura',
            '${PlanLight.heightOf(el).toStringAsFixed(2)} m',
            current: PlanLight.heightOf(el),
            min: 0.3,
            max: 15,
            onChanged: (v) =>
                el.props[PlanLight.heightKey] = (v * 20).round() / 20,
          )
        else
          Text(
            'Cuelga del truss a ${PlanLight.heightOf(el).toStringAsFixed(2)} m.',
            style: AppTypography.caption(palette),
          ),
        slider(
          'Hacia dónde mira',
          '${el.rotation.round()}°',
          current: el.rotation,
          min: 0,
          max: 359,
          onChanged: (v) => el.rotation = v.roundToDouble(),
        ),
        if (overhead)
          slider(
            'Inclinación desde la vertical',
            '${PlanLight.tiltOf(el).round()}°',
            current: PlanLight.tiltOf(el),
            min: 0,
            max: 80,
            onChanged: (v) => el.props[PlanLight.tiltKey] = v.roundToDouble(),
          ),
      ],
    );
  }
}

class _ViewTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _ViewTile({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Material(
      color: selected
          ? palette.accent.withValues(alpha: 0.18)
          : palette.surfaceElevated,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: selected ? palette.accent : palette.border),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: selected ? palette.accent : palette.textSecondary,
            ),
            Text(label, style: AppTypography.caption(palette)),
          ],
        ),
      ),
    );
  }
}

/// El 3D a pantalla entera, con todas las opciones a la vista. En el iPad
/// es la pantalla del 3D; en el Mac se abre desde el panel. Lo que se
/// mueve o se retoca aquí se guarda en la planta.
class Plan3dScreen extends StatefulWidget {
  final List<PlanElement> elements;
  final double metersPerUnit;
  final String? name;
  final PlanElement? selected;
  final ValueChanged<PlanElement?>? onSelect;
  final Future<void> Function(PlanElement)? onChanged;
  final Future<void> Function(PlanElement)? onAdd;
  final PlanAmbient? ambient;
  final UnrealWorld? unrealWorld;
  final UnrealCaptureSink? onUnrealCapture;
  final Future<void> Function()? onOpenUnreal;

  const Plan3dScreen({
    super.key,
    required this.elements,
    required this.metersPerUnit,
    this.name,
    this.selected,
    this.onSelect,
    this.onChanged,
    this.onAdd,
    this.ambient,
    this.unrealWorld,
    this.onUnrealCapture,
    this.onOpenUnreal,
  });

  static Future<void> show(
    BuildContext context, {
    required List<PlanElement> elements,
    required double metersPerUnit,
    String? name,
    PlanElement? selected,
    ValueChanged<PlanElement?>? onSelect,
    Future<void> Function(PlanElement)? onChanged,
    Future<void> Function(PlanElement)? onAdd,
    PlanAmbient? ambient,
    UnrealWorld? unrealWorld,
    UnrealCaptureSink? onUnrealCapture,
    Future<void> Function()? onOpenUnreal,
  }) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => Plan3dScreen(
        elements: elements,
        metersPerUnit: metersPerUnit,
        name: name,
        selected: selected,
        onSelect: onSelect,
        onChanged: onChanged,
        onAdd: onAdd,
        ambient: ambient,
        unrealWorld: unrealWorld,
        onUnrealCapture: onUnrealCapture,
        onOpenUnreal: onOpenUnreal,
      ),
    ),
  );

  @override
  State<Plan3dScreen> createState() => _Plan3dScreenState();
}

class _Plan3dScreenState extends State<Plan3dScreen> {
  late PlanElement? _selected = widget.selected;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.name == null ? '3D' : '3D · ${widget.name}'),
    ),
    body: Plan3dView(
      elements: widget.elements,
      metersPerUnit: widget.metersPerUnit,
      name: widget.name,
      ambient: widget.ambient,
      onAdd: widget.onAdd == null
          ? null
          : (el) async {
              await widget.onAdd!(el);
              if (mounted) setState(() {});
            },
      selected: _selected,
      onSelect: (el) {
        setState(() => _selected = el);
        widget.onSelect?.call(el);
      },
      onChanged: widget.onChanged == null
          ? null
          : (el) async {
              await widget.onChanged!(el);
              // La escena se rehace con lo guardado.
              if (mounted) setState(() {});
            },
      full: true,
      unrealWorld: widget.unrealWorld,
      onUnrealCapture: widget.onUnrealCapture,
      onOpenUnreal: widget.onOpenUnreal,
    ),
  );
}
