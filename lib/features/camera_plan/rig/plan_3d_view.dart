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
import '../camera_plan_element_model.dart';
import 'plan_scene3d.dart';

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

  /// Pantalla entera, con el lateral de opciones.
  final bool full;

  /// Panel: pasar a pantalla entera.
  final VoidCallback? onExpand;

  /// Panel: cerrar.
  final VoidCallback? onClose;

  const Plan3dView({
    super.key,
    required this.elements,
    required this.metersPerUnit,
    this.name,
    this.selected,
    this.onSelect,
    this.full = false,
    this.onExpand,
    this.onClose,
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
    _debounce?.cancel();
    super.dispose();
  }

  /// La planta cambia a menudo mientras se arrastra: se manda al 3D como
  /// mucho cada 150 ms y solo si ha cambiado.
  void _schedule() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 150), _push);
  }

  Future<void> _push() async {
    final web = _web;
    if (!_ready || web == null || !mounted) return;
    final scene = PlanScene3d.build(
      widget.elements,
      metersPerUnit: widget.metersPerUnit,
      name: widget.name,
    );
    final json = jsonEncode(scene);
    if (json == _sent) return;
    _sent = json;
    setState(() => _scene = scene);
    await web.evaluateJavascript(source: 'iris.load($json);');
    await _pushSelection();
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
            const PopupMenuDivider(),
            for (final (key, label) in _layers)
              CheckedPopupMenuItem(
                value: key,
                checked: _show[key]!,
                child: Text(label),
              ),
          ],
          onSelected: _toggle,
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
        header('Qué se ve'),
        toggle('Cubierta', _roof, () => _toggle('roof')),
        toggle('Conos de luz', _cones, () => _toggle('cones')),
        for (final (key, label) in _layers)
          toggle(label, _show[key]!, () => _toggle(key)),
        header('En la escena'),
        ..._summary(palette),
        header('Selección'),
        Text(
          _selected == null
              ? 'Toca algo en el 3D para seleccionarlo también en la planta.'
              : _selected!.displayLabel,
          style: AppTypography.bodyMedium(palette),
        ),
        header('Exportar'),
        OutlinedButton.icon(
          icon: const Icon(Icons.ios_share, size: 16),
          label: const Text('glTF (.glb) para Unreal'),
          onPressed: _exportGlb,
        ),
      ],
    );
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
/// es la pantalla del 3D; en el Mac se abre desde el panel.
class Plan3dScreen extends StatelessWidget {
  final List<PlanElement> elements;
  final double metersPerUnit;
  final String? name;
  final PlanElement? selected;
  final ValueChanged<PlanElement?>? onSelect;

  const Plan3dScreen({
    super.key,
    required this.elements,
    required this.metersPerUnit,
    this.name,
    this.selected,
    this.onSelect,
  });

  static Future<void> show(
    BuildContext context, {
    required List<PlanElement> elements,
    required double metersPerUnit,
    String? name,
    PlanElement? selected,
    ValueChanged<PlanElement?>? onSelect,
  }) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => Plan3dScreen(
        elements: elements,
        metersPerUnit: metersPerUnit,
        name: name,
        selected: selected,
        onSelect: onSelect,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(name == null ? '3D' : '3D · $name')),
    body: Plan3dView(
      elements: elements,
      metersPerUnit: metersPerUnit,
      name: name,
      selected: selected,
      onSelect: onSelect,
      full: true,
    ),
  );
}
