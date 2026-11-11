import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'
    show Clipboard, ClipboardData, PlatformException;
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../../scan_jobs/capture_store.dart';
import 'scan_direct.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_layout.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/export_file_saver.dart';
import '../camera_plan_constants.dart';
import '../camera_plan_element_model.dart';
import '../light/ambient.dart';
import '../../../core/settings/app_prefs.dart';
import '../light/exposure.dart';
import '../plan_prefs.dart';
import '../set_environment.dart';
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
import '../../unreal_link/unreal_stage_package.dart';
import '../../unreal_link/unreal_stage_payload.dart';
import '../../unreal_link/unreal_thumbs.dart';
import '../../../core/sync/plan_scan_store.dart';
import '../../../core/utils/media_storage.dart';
import '../plan_segment.dart';
import '../plan_data.dart';
import '../plan_target.dart';
import 'plan_3d_shots.dart';
import 'plan_transform.dart';
import 'plan_transform_fields.dart';
import 'scan_builder_sheet.dart';
import 'scan_capture_channel.dart';
import 'scan_store.dart';
import 'scan_usdz.dart';
import 'scan_capture.dart';
import 'scan_review.dart';
import 'scan_review_sheet.dart';
import 'scan_structure.dart';
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
  ('props', 'Mobiliario y atrezzo'),
];

/// La planta en 3D: three.js en un WebView, empaquetado en la app para que
/// funcione sin red (`assets/viewer3d/`). Recibe la escena resuelta
/// ([PlanScene3d]) cada vez que la planta cambia y avisa de lo que se toca
/// en el 3D para seleccionarlo también en la planta.
///
/// En panel (junto a la planta) la barra es compacta; a pantalla entera
/// ([full]) lleva un lateral con todas las opciones y el resumen.
/// Recibe la cenital de un escaneo: el PNG y su rectángulo en metros de la
/// planta.
typedef ScanTopSink = Future<void> Function(Uint8List png, Rect metres);

/// Guarda una captura del iPhone en la planta (su set o localización) y
/// devuelve el texto que se enseña.
typedef CaptureSink = Future<String> Function(String path);

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

  /// Proyecto de la planta: sus miniaturas de Unreal.
  final int? projectId;

  /// Pone la cenital de un escaneo (PNG) de fondo en la planta, en el
  /// rectángulo dado en metros de la planta.
  final ScanTopSink? onScanTop;

  /// Captura guiada del iPhone: sin él, el .zip solo se comparte.
  final CaptureSink? onCapture;

  /// La cámara con la que se mide y su diafragma (F6.21.4).
  final ExposureSettings? exposure;
  final double? stop;

  /// Plató, interior o exterior (F6.21.1).
  final SetEnvironment? environment;

  /// Guarda lo decidido de un recinto (la altura del techo que sale del
  /// escaneo, ES.3).
  final Future<void> Function(RoomSetting)? onRoom;

  /// La planta abierta (un set o un plano): con ella, el 3D lleva encima la
  /// tira de planos y salta a sus cámaras sin volver al 2D (ED.3).
  final PlanTarget? navTarget;

  /// Abre otra planta (un plano, un set o una escena) sin salir del 3D.
  final ValueChanged<PlanTarget>? onNavigate;

  /// Al cargar, mirar por la cámara del plano abierto.
  final bool lookThrough;

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
    this.projectId,
    this.onScanTop,
    this.onCapture,
    this.exposure,
    this.stop,
    this.environment,
    this.onRoom,
    this.navTarget,
    this.onNavigate,
    this.lookThrough = false,
  });

  static const asset = 'assets/viewer3d/index.html';

  @override
  State<Plan3dView> createState() => _Plan3dViewState();
}

class _Plan3dViewState extends State<Plan3dView> {
  InAppWebViewController? _web;

  /// iPhone a pantalla entera: panel de ajustes abierto sobre el visor.
  bool _panelOpen = false;
  bool _ready = false;
  String? _sent;
  Map<String, dynamic>? _scene;
  Timer? _debounce;
  String _view = 'iso';
  bool _cones = true;

  /// Ya se miró por la cámara del plano al abrirlo ([Plan3dView.lookThrough]).
  bool _lookedThrough = false;

  /// Luz real (con la exposición de la cámara) o luz de trabajo (F6.21.4).
  bool _realLight = true;

  /// La EV100 con la que expone el 3D, si va con luz real.
  double? _ev100;
  bool _roof = true;

  /// Etiquetas con el nombre de cada pieza (la del seleccionado, siempre).
  bool _names = false;
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

  /// iPhone o iPad con ARKit: captura guiada (F6.20 E6).
  bool _canCapture = false;

  @override
  void initState() {
    super.initState();
    _realLength.addListener(() => setState(() {}));
    _fromUnreal = UnrealLink.instance.edits.listen(_applyFromUnreal);
    _scanArrivals = PlanScanStore.arrivals.listen(
      (file) => _call('iris.rescan(${jsonEncode(file)});'),
    );
    UnrealThumbs.instance.addListener(_onThumbs);
    unawaited(_shareScanFolders());
    unawaited(
      ScanCaptureChannel.isSupported().then((ok) {
        if (ok && mounted) setState(() => _canCapture = true);
      }),
    );
    _schedule();
  }

  StreamSubscription<String>? _scanArrivals;

  /// Huella de la estructura ya guardada para Unreal, y espera tras el
  /// último cambio antes de exportarla de nuevo.
  String? _structureKey;
  Timer? _structureTimer;

  /// Con Unreal conectado, la estructura del set (paredes, huecos, techos,
  /// telas, truss) va a Unreal como malla cuando cambia (F6.21.3).
  void _offerStructure(Map<String, dynamic> scene) {
    final key = PlanScene3d.structureKey(scene);
    if (key == null || key == _structureKey) return;
    if (!UnrealLink.instance.isOn || widget.projectId == null) return;
    _structureTimer?.cancel();
    _structureTimer = Timer(const Duration(seconds: 2), () async {
      final web = _web, projectId = widget.projectId;
      if (!mounted || web == null || !_ready || projectId == null) return;
      final result = await web.callAsyncJavaScript(
        functionBody: 'return await iris.structureGlb();',
      );
      final b64 = result?.value;
      if (b64 is! String || b64.isEmpty) return;
      final path = await MediaStorage.writeProjectFileBytes(
        projectId: projectId,
        subfolder: 'unreal_sets',
        bytes: base64Decode(b64),
        fileName: '$key.glb',
      );
      _structureKey = key;
      UnrealStagePayload.structure = {
        'file': '$key.glb',
        'folder': File(path).parent.path,
      };
      if (mounted) _schedule();
    });
  }

  /// Unreal, en este mismo PC, importa los escaneos de estas carpetas.
  Future<void> _shareScanFolders() async {
    final projectId = widget.projectId;
    final folders = <String>[
      if (projectId != null)
        if (await PlanScanStore.pathFor(projectId, 'x.glb') case final path?)
          File(path).parent.path,
      (await ScanStore.dir()).path,
    ];
    UnrealStagePayload.scanFolders = folders;
  }

  @override
  void didUpdateWidget(Plan3dView old) {
    super.didUpdateWidget(old);
    _schedule();
    if (old.selected != widget.selected) {
      _selected = widget.selected;
      _pushSelection();
      // En el iPhone, tocar una pieza abre sus ajustes.
      if (widget.selected != null) _panelOpen = true;
    }
  }

  @override
  void dispose() {
    _fromUnreal?.cancel();
    _scanArrivals?.cancel();
    _structureTimer?.cancel();
    UnrealThumbs.instance.removeListener(_onThumbs);
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

  Map<String, dynamic> _buildScene() => PlanScene3d.build(
    widget.elements,
    metersPerUnit: widget.metersPerUnit,
    exposure: widget.exposure,
    stop: widget.stop,
    environment: widget.environment,
    name: widget.name,
    ambient: widget.ambient,
  );

  Future<void> _push() async {
    if (!mounted) return;
    final scene = _buildScene();
    // Unreal recibe la misma escena, esté o no listo el visor (siempre con
    // la exposición: la luz de trabajo es solo para el visor).
    // Otra estructura (otro set, o una pared movida): la anterior no se
    // manda mientras se exporta la nueva.
    if (PlanScene3d.structureKey(scene) != _structureKey) {
      UnrealStagePayload.structure = null;
    }
    UnrealLink.instance.offer(scene, world: widget.unrealWorld);
    _offerStructure(scene);
    if (!_realLight) scene['lightMode'] = 'work';
    final web = _web;
    if (!_ready || web == null) return;
    final json = jsonEncode(scene);
    if (json == _sent) return;
    _sent = json;
    setState(() => _scene = scene);
    await web.evaluateJavascript(source: 'iris.load($json);');
    if (widget.lookThrough && !_lookedThrough && _cameras.isNotEmpty) {
      _lookedThrough = true;
      _setView('cam:${_cameras.first.$1}');
    }
    unawaited(_sendThumbs());
    await _pushSelection();
    if (_floor) unawaited(_pushFloor());
  }

  /// Miniaturas 3/4 ya mandadas al visor.
  final _sentThumbs = <String>{};

  /// Manda al visor las miniaturas que pide la escena y aún no tiene: van
  /// una vez, como imagen, y el visor rehace el atrezzo con ellas.
  Future<void> _sendThumbs() async {
    final projectId = widget.projectId;
    final scene = _scene;
    if (projectId == null || scene == null || !_ready) return;
    final out = <String, String>{};
    for (final p in (scene['props'] as List? ?? const []).cast<Map>()) {
      final key = p['thumb'] as String?;
      if (key == null || _sentThumbs.contains(key)) continue;
      final file = UnrealThumbs.instance.file(projectId, key);
      if (file == null) continue;
      try {
        out[key] =
            'data:image/png;base64,${base64Encode(await File(file).readAsBytes())}';
        _sentThumbs.add(key);
      } catch (_) {}
    }
    if (out.isNotEmpty) await _call('iris.thumbs(${jsonEncode(out)});');
  }

  void _onThumbs() {
    // Una miniatura nueva (o rehecha): se vuelve a mandar.
    _sentThumbs.clear();
    unawaited(_sendThumbs());
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
          'names': _names,
          'show': _show,
          'nav':
              AppPrefs.instance.get(
                PlanPrefs.unrealNav,
                projectId: widget.projectId,
              )
              ? 'unreal'
              : 'orbit',
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
          projectId: widget.projectId,
        ).then((bytes) => bytes == null ? null : base64Encode(bytes));
      case 'lightMode':
        final ev = message['ev100'];
        if (mounted) {
          setState(
            () => _ev100 = message['physical'] == true && ev is num
                ? ev.toDouble()
                : null,
          );
        }
      case 'scanError':
        if (mounted) {
          setState(() => _status = 'Escaneo: ${message['message']}');
        }
      case 'move' || 'aim' || 'rotate' || 'lift':
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
    } else if (message['type'] == 'rotate') {
      if (!PlanTransform.canRotate(el)) return;
      PlanTransform.setRotation(el, el.rotation + n('deg'));
    } else if (message['type'] == 'lift') {
      PlanTransform.liftBy(el, n('dz'));
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
      allowedExtensions: [...PlanScan.formats, if (ScanUsdz.supported) 'usdz'],
    );
    final path = picked?.files.single.path;
    if (path == null) return;
    final name = path.split(Platform.pathSeparator).last;
    if (!ScanUsdz.isUsdz(path)) return _addScan(path, name);
    setState(() => _status = 'Convirtiendo el USDZ…');
    final String obj;
    try {
      obj = await ScanUsdz.toObj(path);
    } on PlatformException catch (e) {
      if (mounted) {
        setState(() => _status = 'No se pudo abrir el USDZ: ${e.message}');
      }
      return;
    }
    await _addScan(obj, name);
    await ScanUsdz.discard(obj);
  }

  /// Crea un escaneo con RealityScan a partir de fotos o vídeo (F6.20 E) y
  /// lo pone en la planta como uno importado.
  Future<void> _buildScan() async {
    if (widget.onAdd == null) return;
    final result = await ScanBuilderSheet.show(context);
    if (result == null) return;
    await _addScan(
      result.irisGlb,
      result.folder.split(Platform.pathSeparator).last,
      unrealPath: result.highGlb,
    );
    if (mounted) {
      setState(
        () => _status = result.metric
            ? 'Escaneo en metros reales (captura del iPhone): no hace falta '
                  'calibrarlo.'
            : 'Escaneo puesto. Calíbralo con una medida antes de proponer '
                  'paredes.',
      );
    }
  }

  /// Captura guiada con el iPhone (F6.20 E6). Queda pendiente en la planta
  /// y pasa sola al PC con RealityScan; sin planta, se comparte el .zip.
  Future<void> _captureWithPhone() async {
    // Se toma antes: si al terminar este visor ya no existe (la planta se
    // rehízo al girar el móvil), la captura se guarda igual.
    final save = widget.onCapture;
    final name = widget.name ?? 'Localización';
    final ultraWide = await ScanCaptureChannel.chooseLens(context);
    if (ultraWide == null) return;
    final path = await ScanCaptureChannel.start(name, ultraWide: ultraWide);
    if (path == null) return;
    if (save != null) {
      String status;
      try {
        status = await save(path);
      } catch (e) {
        status = 'No se pudo guardar la captura ($e). Las fotos siguen en '
            'el iPhone: recupéralas desde el panel de escaneo del set.';
      }
      if (mounted) setState(() => _status = status);
      return;
    }
    if (!mounted) return;
    setState(
      () => _status =
          'Captura guardada. Pásala al PC y ábrela en «Crear escaneo» → '
          '«Captura del iPhone».',
    );
    await Share.shareXFiles([
      XFile(path),
    ], subject: 'Captura de localización de IRIS');
  }

  /// [unrealPath]: la malla con todo el detalle, que Unreal usa en vez de
  /// la de IRIS (F6.20 E5).
  Future<void> _addScan(String path, String name, {String? unrealPath}) async {
    final add = widget.onAdd;
    if (add == null) return;
    final file = await ScanStore.import(path, projectId: widget.projectId);
    if (unrealPath != null && await File(unrealPath).exists()) {
      await ScanStore.saveUnrealVersion(file, unrealPath);
    }
    // Construido desde una captura del iPhone: su carpeta queda al lado
    // (`captura`), con las fotos que se enseñan al revisar.
    final captureDir = '${File(path).parent.path}/captura';
    final hasCapture = CapturePackage.isCapture(captureDir);
    final size = await File(path).length();
    if (mounted) {
      setState(
        () => _status = widget.projectId == null
            ? 'Escaneo importado (solo en este equipo).'
            : PlanScanStore.fitsCloud(size)
            ? 'Escaneo importado; se sube a la nube para el resto de equipos.'
            : 'Escaneo importado, pero pesa '
                  '${(size / 1048576).round()} MB: no se sube a la nube '
                  '(máximo 50). Expórtalo con menos detalle para usarlo en '
                  'otros equipos.',
      );
    }
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
      name: name,
    );
    if (hasCapture) scan.props[PlanScan.captureKey] = captureDir;
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
        if (widget.onAdd != null && ScanBuilderSheet.supported)
          OutlinedButton.icon(
            icon: const Icon(Icons.photo_camera_back_outlined, size: 16),
            label: const Text('Crear escaneo desde fotos o vídeo'),
            onPressed: _buildScan,
          ),
        if (widget.onAdd != null && widget.projectId != null)
          OutlinedButton.icon(
            key: const ValueKey('plan-from-capture'),
            icon: const Icon(Icons.architecture, size: 16),
            label: const Text('Sacar la planta de una captura'),
            onPressed: _planFromCapture,
          ),
        if (_canCapture) ...[
          FilledButton.icon(
            icon: const Icon(Icons.photo_camera_outlined, size: 16),
            label: const Text('Capturar localización con el iPhone'),
            onPressed: _captureWithPhone,
          ),
          Text(
            'Recorre el sitio despacio: las fotos se hacen solas y la app '
            'avisa de lo que falta. Luego manda el .zip al PC y ábrelo en '
            '«Crear escaneo» → «Captura del iPhone»: sale en metros reales.',
            style: caption,
          ),
        ],
        Text(
          'De RealityScan, Polycam o Luma AI: exporta en GLB (o OBJ) con '
          'texturas y, para que viaje a otros equipos, de menos de 50 MB '
          '(en RealityScan, detalle medio). El USDZ del iPhone no vale: '
          'expórtalo como GLB. Luego tócalo para colocarlo, girarlo y '
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
      if (widget.onScanTop != null) ...[
        const SizedBox(height: AppSpacing.sm),
        OutlinedButton.icon(
          icon: const Icon(Icons.layers_outlined, size: 16),
          label: const Text('Cenital de fondo en la planta'),
          onPressed: () => _scanTop(el),
        ),
        Text(
          'Una vista desde arriba del escaneo, a escala, debajo de la planta '
          'para calcar paredes y muebles. Calíbralo antes.',
          style: caption,
        ),
      ],
      if (widget.onAdd != null) ...[
        const SizedBox(height: AppSpacing.sm),
        OutlinedButton.icon(
          icon: const Icon(Icons.border_outer, size: 16),
          label: const Text('Revisar el escaneo'),
          onPressed: () => _reviewScan(el),
        ),
        Text(
          'Paredes, puertas, ventanas, techo y muebles sacados del escaneo, '
          'para aceptarlos o corregirlos. Calíbralo antes.',
          style: caption,
        ),
      ],
      if (widget.onChanged != null) ...[
        const SizedBox(height: AppSpacing.sm),
        OutlinedButton.icon(
          icon: const Icon(Icons.straighten, size: 16),
          label: const Text('Ajustar mis paredes al escaneo'),
          onPressed: () => _snapWalls(el),
        ),
      ],
    ];
  }

  /// Llama al visor con [source] y lee el JSON que devuelve.
  Future<Object?> _ask(String source) async {
    final raw = await _web?.evaluateJavascript(source: source);
    return raw is String ? jsonDecode(raw) : null;
  }

  /// Lleva puntos (x, y, z seguidos) por `iris.scanToPlan` o
  /// `iris.planToScan` del escaneo [id].
  Future<List<double>?> _mapPoints(String fn, String id, List<double> pts) async {
    final data = await _ask('iris.$fn(${jsonEncode(id)}, ${jsonEncode(pts)});');
    return data is List ? [for (final v in data) (v as num).toDouble()] : null;
  }

  /// Mide el escaneo [el] y saca su estructura (ES.2), con la captura del
  /// iPhone si se construyó en este equipo. Null si no está cargado.
  Future<
    ({
      String id,
      ScanProfile profile,
      ScanStructure structure,
      CapturePackage? capture,
    })?
  >
  _measureScan(PlanElement el) async {
    if (_web == null || !_ready) return null;
    final id = PlanScene3d.idOf(el, widget.elements.indexOf(el));
    setState(() => _status = 'Midiendo el escaneo…');
    final raw = await _ask('iris.scanProfile(${jsonEncode(id)}, 0.1);');
    var profile = raw is Map ? ScanProfile.fromJson(raw) : null;
    if (profile == null) {
      if (mounted) {
        setState(() => _status = 'El escaneo aún no se ha cargado en el 3D.');
      }
      return null;
    }
    final captureDir = PlanScan.capture(el);
    final capture = captureDir == null ? null : CapturePackage.read(captureDir);
    CaptureHints? hints;
    if (capture != null) {
      hints = CaptureHints(exterior: capture.exterior);
      if (capture.hasStructure) {
        final mapped = await _mapPoints(
          'scanToPlan',
          id,
          capture.hintPoints(),
        );
        if (mapped != null) hints = capture.hintsFrom(mapped);
      }
    }
    // Primera pasada para el suelo y el techo; con ellos, la rejilla de los
    // muebles.
    final first = solveStructure(profile, capture: hints);
    final grid = await _ask(
      'iris.scanGrid(${jsonEncode(id)}, ${first.floorY + 0.05}, '
      '${first.floorY + first.heightM - 0.15}, 0.1);',
    );
    profile = profile.withGrid(grid is Map ? ScanGrid.fromJson(grid) : null);
    return (
      id: id,
      profile: profile,
      structure: solveStructure(profile, capture: hints),
      capture: capture,
    );
  }

  /// La luz que había al escanear, en palabras: temperatura y cantidad.
  static String? _lightNote(CapturePackage c) {
    final k = c.kelvin, i = c.lightIntensity;
    if (k == null && i == null) return null;
    final parts = [
      if (k != null) '${(k / 100).round() * 100} K',
      if (i != null)
        i < 150
            ? 'muy poca luz'
            : i < 500
            ? 'poca luz'
            : 'luz normal',
    ];
    return 'Al escanear: ${parts.join(', ')} (estimado por el iPhone).';
  }

  /// «Pegar al escaneo» (ES.3): las paredes dibujadas a mano se ajustan a
  /// la recta y el grosor de la pared del escaneo que tienen al lado.
  Future<void> _snapWalls(PlanElement el) async {
    final changed = widget.onChanged;
    if (changed == null) return;
    final m = await _measureScan(el);
    if (m == null) return;
    final mpu = widget.metersPerUnit;
    var n = 0;
    for (final w in widget.elements) {
      if (!PlanSegment.isSegment(w) ||
          PlanSegment.kind(w) != PlanSegment.kindWall ||
          PlanSegment.curve(w) != 0 ||
          w.props[kScanSourceKey] == kScanSourceValue) {
        continue;
      }
      final snap = snapToScan(
        PlanSegment.start(w) * mpu,
        PlanSegment.end(w) * mpu,
        m.structure,
      );
      if (snap == null) continue;
      w.position = snap.start / mpu;
      PlanSegment.setEnd(w, snap.end / mpu);
      w.props[kScanThicknessKey] = (snap.thickness * 100).round() / 100;
      await changed(w);
      n++;
    }
    if (mounted) {
      setState(
        () => _status = n == 0
            ? 'Ninguna pared tuya está junto a una pared del escaneo.'
            : '$n paredes ajustadas al escaneo.',
      );
    }
  }

  /// Revisión del escaneo (ES.3): el solucionador saca paredes, huecos y
  /// muebles; se revisan sobre el lienzo, con la foto del sitio en lo
  /// dudoso, y lo aceptado entra en la planta.
  Future<void> _reviewScan(PlanElement el) async {
    final add = widget.onAdd;
    if (add == null) return;
    final m = await _measureScan(el);
    if (m == null) return;
    final (:id, :profile, :structure, :capture) = m;

    final top = await _ask('iris.scanTop(${jsonEncode(id)}, 2048);');
    double n(Object? v) => (v as num).toDouble();
    final topOk = top is Map && top['png'] is String;

    // El corte a 1 m, de fondo.
    var cut = const <(Offset, Offset)>[];
    var bestGap = double.infinity;
    for (var k = 0; k < profile.heights.length; k++) {
      final gap = (profile.heights[k] - structure.floorY - 1).abs();
      if (gap < bestGap) {
        bestGap = gap;
        cut = profile.slices[k];
      }
    }

    if (!mounted) return;
    setState(() => _status = null);
    final result = await ScanReviewSheet.show(
      context,
      structure: structure,
      lightNote: capture == null ? null : _lightNote(capture),
      cut: cut,
      topPng: topOk ? base64Decode(top['png'] as String) : null,
      topRect: topOk
          ? Rect.fromLTWH(n(top['x']), n(top['y']), n(top['w']), n(top['h']))
          : null,
      findPhoto: capture == null || capture.frames.isEmpty
          ? null
          : (item) async {
              final world = await _mapPoints('planToScan', id, [
                for (final p in reviewPoints(structure, item)) ...p,
              ]);
              if (world == null) return null;
              final view = bestPhoto(capture.frames, [
                for (var i = 0; i + 2 < world.length; i += 3)
                  world.sublist(i, i + 3),
              ]);
              if (view == null) return null;
              return (path: '${capture.dir}/${view.frame.file}', view: view);
            },
    );
    if (result == null) return;
    await _addReviewed(structure, result, add);
  }

  /// La planta sin PC (ES.A): de una captura ya hecha, con sus planos y sus
  /// toques, a la misma revisión que un escaneo.
  Future<void> _planFromCapture() async {
    final add = widget.onAdd;
    final projectId = widget.projectId;
    if (add == null || projectId == null) return;
    final db = ProviderScope.containerOf(context).read(databaseProvider);
    final rows = await db.watchCapturesForProject(projectId).first;
    final here = <LocationCapture>[];
    for (final row in rows) {
      final uid = row.uid;
      if (uid != null && await (await CaptureStore.zipFor(uid)).exists()) {
        here.add(row);
      }
    }
    if (!mounted) return;
    if (here.isEmpty) {
      setState(() => _status = 'No hay capturas guardadas en este equipo.');
      return;
    }
    final row = here.length == 1
        ? here.single
        : await showDialog<LocationCapture>(
            context: context,
            builder: (ctx) => SimpleDialog(
              title: const Text('¿De qué captura?'),
              children: [
                for (final c in here)
                  SimpleDialogOption(
                    onPressed: () => Navigator.pop(ctx, c),
                    child: Text('${c.name} · ${c.photoCount} fotos'),
                  ),
              ],
            ),
          );
    if (row == null) return;
    final uid = row.uid!;
    final capture = await CaptureStore.readPackage(uid);
    if (!mounted) return;
    if (capture == null || !capture.hasStructure) {
      setState(
        () => _status =
            'Esta captura no guardó paredes ni toques. Hazla de nuevo con '
            'la app actual, marcando las esquinas con «Marcar».',
      );
      return;
    }
    final plan = solveCaptureDirect(capture);
    if (plan == null) {
      setState(
        () => _status =
            'No se ha visto ninguna pared. Marca al menos tres esquinas en '
            'la captura.',
      );
      return;
    }
    final result = await ScanReviewSheet.show(
      context,
      structure: plan.structure,
      cut: plan.cut,
      lightNote: _lightNote(capture),
      findPhoto: capture.frames.isEmpty
          ? null
          : (item) async {
              final view = bestPhoto(
                capture.frames,
                reviewPoints(plan.structure, item),
              );
              if (view == null) return null;
              final path = await CaptureStore.extractPhoto(
                uid,
                view.frame.file,
                capture.dir,
              );
              return path == null ? null : (path: path, view: view);
            },
    );
    if (result == null) return;
    await _addReviewed(
      movedStructure(plan.structure, _landingDelta(plan.structure)),
      result,
      add,
    );
  }

  /// Cuánto mover una estructura medida en el mundo de ARKit para que caiga
  /// sobre lo que ya hay en la planta o, si está vacía, en el centro de la
  /// vista inicial del lienzo.
  Offset _landingDelta(ScanStructure s) {
    final mpu = widget.metersPerUnit;
    var from = Offset.infinite, to = -Offset.infinite;
    void grow(Offset p) {
      from = Offset(math.min(from.dx, p.dx), math.min(from.dy, p.dy));
      to = Offset(math.max(to.dx, p.dx), math.max(to.dy, p.dy));
    }

    for (final w in s.walls) {
      grow(w.start);
      grow(w.end);
    }
    final center = (from + to) / 2;
    if (widget.elements.isEmpty) return const Offset(12, 8) - center;
    from = Offset.infinite;
    to = -Offset.infinite;
    for (final e in widget.elements) {
      grow(e.position * mpu);
    }
    return (from + to) / 2 - center;
  }

  Future<void> _addReviewed(
    ScanStructure structure,
    ScanReviewResult result,
    Future<void> Function(PlanElement) add,
  ) async {
    final mpu = widget.metersPerUnit;
    final elements = reviewElements(structure, result.items, mpu);
    for (final e in elements) {
      await add(e);
    }
    final inside = interiorPoint(structure);
    if (inside != null && widget.onRoom != null) {
      await widget.onRoom!(
        // En la calle, a cielo abierto; en un local, con su techo.
        RoomSetting(
          x: inside.dx / mpu,
          y: inside.dy / mpu,
          openSky: structure.exterior,
          ceilingM: structure.exterior
              ? null
              : (result.heightM * 100).round() / 100,
        ),
      );
    }
    if (mounted) {
      setState(
        () => _status =
            '${elements.length} elementos añadidos a la planta desde el '
            'escaneo, con el techo a ${result.heightM.toStringAsFixed(2)} m.',
      );
    }
  }

  /// Pide al visor la cenital del escaneo [el] y la pone de fondo.
  Future<void> _scanTop(PlanElement el) async {
    final web = _web, sink = widget.onScanTop;
    if (web == null || !_ready || sink == null) return;
    final id = PlanScene3d.idOf(el, widget.elements.indexOf(el));
    final raw = await web.evaluateJavascript(
      source: 'iris.scanTop(${jsonEncode(id)}, 2048);',
    );
    final data = raw is String ? jsonDecode(raw) : null;
    if (data is! Map || data['png'] is! String) {
      if (mounted) {
        setState(() => _status = 'El escaneo aún no se ha cargado en el 3D.');
      }
      return;
    }
    double n(Object? v) => (v as num).toDouble();
    await sink(
      base64Decode(data['png'] as String),
      Rect.fromLTWH(n(data['x']), n(data['y']), n(data['w']), n(data['h'])),
    );
    if (mounted) {
      setState(() => _status = 'Cenital puesta de fondo en la planta.');
    }
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

  /// Todo el set en un archivo que Unreal abre sin enlace en vivo: para
  /// llevarlo a otro PC o guardarlo con el proyecto.
  Future<void> _exportStagePackage() async {
    final web = _web;
    if (web == null || !_ready) return;
    setState(() => _status = 'Preparando el paquete…');
    final result = await web.callAsyncJavaScript(
      functionBody: 'return await iris.structureGlb();',
    );
    final b64 = result?.value;
    await _shareScanFolders();
    final payload = UnrealStagePayload.build(
      _buildScene(),
      world: widget.unrealWorld,
    );
    final bytes = await UnrealStagePackage.buildInBackground(
      payload: payload,
      structureGlb: b64 is String && b64.isNotEmpty ? base64Decode(b64) : null,
      scans: await UnrealStagePackage.collectScans(
        (payload['scans'] as List).cast<Map>(),
        UnrealStagePayload.scanFolders,
      ),
    );
    final base = (widget.name ?? 'planta').replaceAll(RegExp(r'[^\w\- ]'), '');
    final path = await ExportFileSaver.saveBytes(
      bytes: bytes,
      dialogTitle: 'Guardar el paquete para Unreal',
      fileName: base,
      extension: UnrealStagePackage.extension,
    );
    if (!mounted) return;
    setState(() => _status = null);
    if (path == null) return;
    final command = UnrealStagePackage.importCommand(path);
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Paquete guardado'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'En Unreal, con IRIS Stage instalado, pega esto en la consola '
              'de Python. Si llevas el archivo a otro equipo, cambia la ruta.',
            ),
            const SizedBox(height: AppSpacing.sm),
            SelectableText(command),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
          FilledButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: command));
              Navigator.pop(context);
            },
            child: const Text('Copiar orden'),
          ),
        ],
      ),
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
    final navTarget = widget.navTarget, projectId = widget.projectId;
    final Widget stage = navTarget == null || projectId == null
        ? viewer
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PlanDataBuilder(
                projectId: projectId,
                builder: (context, data) => Plan3dShotStrip(
                  nav: Plan3dNav.of(data, navTarget, widget.elements),
                  view: _view,
                  onView: _setView,
                  onNavigate: widget.onNavigate,
                ),
              ),
              Expanded(child: viewer),
            ],
          );
    if (widget.full) {
      return LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth >= AppLayout.compactBreakpoint) {
            return Material(
              color: palette.surface,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: stage),
                  VerticalDivider(width: 1, color: palette.divider),
                  SizedBox(width: 300, child: _sidebar(palette)),
                ],
              ),
            );
          }
          // iPhone: el visor a todo el ancho y los ajustes en un panel
          // inferior plegable, en el mismo árbol para que se redibuje.
          return Material(
            color: palette.surface,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _compactBar(
                  palette,
                  onSettings: () => setState(() => _panelOpen = !_panelOpen),
                ),
                Divider(height: 1, color: palette.divider),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, area) => Stack(
                      children: [
                        Positioned.fill(child: stage),
                        if (_panelOpen)
                          Positioned(
                            left: 0,
                            right: 0,
                            bottom: 0,
                            height: area.maxHeight * 0.55,
                            child: _bottomPanel(palette),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      );
    }
    return Material(
      color: palette.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _compactBar(palette),
          Divider(height: 1, color: palette.divider),
          Expanded(child: stage),
        ],
      ),
    );
  }

  // ── Panel junto a la planta: lo justo, sin desbordar ─────────────────────

  Widget _bottomPanel(AppPalette palette) => Material(
    color: palette.surface,
    elevation: 8,
    shape: RoundedRectangleBorder(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      side: BorderSide(color: palette.divider),
    ),
    clipBehavior: Clip.antiAlias,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          onTap: () => setState(() => _panelOpen = false),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.xs,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Ajustes del 3D',
                    style: AppTypography.label(palette),
                  ),
                ),
                Icon(Icons.expand_more, color: palette.textSecondary),
              ],
            ),
          ),
        ),
        Divider(height: 1, color: palette.divider),
        Expanded(child: _sidebar(palette)),
      ],
    ),
  );

  Widget _compactBar(AppPalette palette, {VoidCallback? onSettings}) => Padding(
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
        // Luz o maqueta, a mano (CA.1): antes solo estaba en el panel.
        IconButton(
          tooltip: _realLight
              ? 'Ver como maqueta, para colocar'
              : 'Ver con la luz de los focos',
          icon: Icon(
            _realLight ? Icons.view_in_ar_outlined : Icons.lightbulb_outline,
            size: 18,
            color: palette.textSecondary,
          ),
          onPressed: () => setState(() {
            _realLight = !_realLight;
            _schedule();
          }),
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
              value: 'names',
              checked: _names,
              child: const Text('Nombres'),
            ),
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
        if (onSettings != null)
          IconButton(
            tooltip: 'Ajustes del 3D',
            icon: Icon(
              _panelOpen ? Icons.tune : Icons.tune_outlined,
              size: 20,
              color: _panelOpen ? palette.accent : palette.textSecondary,
            ),
            onPressed: onSettings,
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
        case 'names':
          _names = !_names;
          _set({'names': _names});
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
        // Dos maneras de ver el set (F6.22.5): con la luz de los focos, como
        // la cámara, o claro, para colocar.
        SegmentedButton<bool>(
          showSelectedIcon: false,
          segments: [
            ButtonSegment(
              value: true,
              icon: const Icon(Icons.lightbulb_outline, size: 16),
              label: Text(
                _ev100 == null
                    ? 'Luz'
                    : 'Luz · EV ${_ev100!.toStringAsFixed(1)}',
              ),
            ),
            const ButtonSegment(
              value: false,
              icon: Icon(Icons.view_in_ar_outlined, size: 16),
              label: Text('Maqueta'),
            ),
          ],
          selected: {_realLight},
          onSelectionChanged: (v) => setState(() {
            _realLight = v.first;
            _schedule();
          }),
        ),
        Text(
          _realLight
              ? 'Solo la luz de los focos (y el sol o el cielo si toca), a la '
                    'exposición de la cámara.'
              : 'Maqueta: todo sólido y con luz pareja, con los nombres y la '
                    'altura de cada foco hasta el suelo, para colocar.',
          style: AppTypography.caption(
            palette,
          ).copyWith(color: palette.textTertiary),
        ),
        toggle('Nombres', _names, () => _toggle('names')),
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
          if (_selected!.type != ElementType.actor)
            _NameField(
              key: ValueKey(_selected),
              element: _selected!,
              onCommit: _update,
            ),
          if (_selected!.type == ElementType.light)
            Text(
              'El asa naranja cambia adónde apunta. Cerca de un truss se '
              'cuelga de él.',
              style: AppTypography.caption(
                palette,
              ).copyWith(color: palette.textTertiary),
            ),
          const SizedBox(height: AppSpacing.sm),
          if (PlanTransform.applies(_selected!))
            PlanTransformFields(
              element: _selected!,
              elements: widget.elements,
              metersPerUnit: widget.metersPerUnit,
              onUpdate: _update,
            ),
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
          UnrealAssetTile(
            element: _selected!,
            link: UnrealLink.instance,
            projectId: widget.projectId,
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
        const SizedBox(height: AppSpacing.xs),
        OutlinedButton.icon(
          icon: const Icon(Icons.inventory_2_outlined, size: 16),
          label: const Text('Paquete para Unreal (.irisstage)'),
          onPressed: _exportStagePackage,
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
/// Nombre libre del elemento seleccionado; se guarda al terminar de
/// escribir.
class _NameField extends StatefulWidget {
  final PlanElement element;
  final Future<void> Function() onCommit;

  const _NameField({super.key, required this.element, required this.onCommit});

  @override
  State<_NameField> createState() => _NameFieldState();
}

class _NameFieldState extends State<_NameField> {
  late final _ctrl = TextEditingController(
    text: widget.element.customName ?? '',
  );

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _commit() {
    if (_ctrl.text.trim() == (widget.element.customName ?? '')) return;
    widget.element.customName = _ctrl.text;
    widget.onCommit();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
    child: TextField(
      controller: _ctrl,
      decoration: InputDecoration(
        isDense: true,
        labelText: 'Nombre',
        hintText: widget.element.typeLabel,
      ),
      onSubmitted: (_) => _commit(),
      onTapOutside: (_) => _commit(),
    ),
  );
}

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
        slider(
          'Inclinación (tilt)',
          PlanLight.tiltLabel(PlanLight.elevationOf(el)),
          current: PlanLight.elevationOf(el),
          min: -90,
          max: 90,
          onChanged: (v) => PlanLight.setElevation(el, v.roundToDouble()),
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

/// La tira de planos encima del 3D (ED.3): cada plano salta a su cámara
/// (tocarlo otra vez pasa a la siguiente); si su cámara no está en este 3D,
/// abre su planta. El menú del título cambia de set o de escena.
class Plan3dShotStrip extends StatelessWidget {
  final Plan3dNav? nav;
  final String view;
  final ValueChanged<String> onView;
  final ValueChanged<PlanTarget>? onNavigate;

  const Plan3dShotStrip({
    super.key,
    required this.nav,
    required this.view,
    required this.onView,
    required this.onNavigate,
  });

  void _tap(Plan3dShot shot) {
    final ids = shot.cameraIds;
    if (ids.isEmpty) {
      if (!shot.open) onNavigate?.call(shot.target);
      return;
    }
    final at = ids.indexOf(view.startsWith('cam:') ? view.substring(4) : '');
    onView('cam:${ids[(at + 1) % ids.length]}');
  }

  @override
  Widget build(BuildContext context) {
    final nav = this.nav;
    if (nav == null) return const SizedBox.shrink();
    final palette = context.palette;
    final looking = view.startsWith('cam:') ? view.substring(4) : null;
    final jumps = onNavigate == null
        ? const <PopupMenuEntry<PlanTarget>>[]
        : <PopupMenuEntry<PlanTarget>>[
            if (nav.sets.length > 1) ...[
              const PopupMenuItem(enabled: false, child: Text('Sets')),
              for (final s in nav.sets)
                CheckedPopupMenuItem(
                  value: s.target,
                  checked: s.current,
                  child: Text(s.label),
                ),
            ],
            if (nav.scenes.length > 1) ...[
              if (nav.sets.length > 1) const PopupMenuDivider(),
              const PopupMenuItem(enabled: false, child: Text('Escenas')),
              for (final s in nav.scenes)
                CheckedPopupMenuItem(
                  value: s.target,
                  checked: s.current,
                  child: Text(s.label),
                ),
            ],
          ];
    final title = Text(
      nav.title,
      overflow: TextOverflow.ellipsis,
      style: AppTypography.label(palette),
    );
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
      decoration: BoxDecoration(
        color: palette.surface,
        border: Border(bottom: BorderSide(color: palette.divider)),
      ),
      child: Row(
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 160),
            child: jumps.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: title,
                  )
                : PopupMenuButton<PlanTarget>(
                    key: const ValueKey('strip3d-jump'),
                    tooltip: 'Cambiar de set o de escena',
                    itemBuilder: (_) => jumps,
                    onSelected: onNavigate,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(child: title),
                          Icon(
                            Icons.arrow_drop_down,
                            size: 18,
                            color: palette.textSecondary,
                          ),
                        ],
                      ),
                    ),
                  ),
          ),
          Expanded(
            child: nav.shots.isEmpty
                ? Text(
                    'Sin planos todavía',
                    style: AppTypography.caption(
                      palette,
                    ).copyWith(color: palette.textTertiary),
                  )
                : ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    children: [
                      for (final shot in nav.shots)
                        Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: _ShotChip3d(
                            key: ValueKey('strip3d-${shot.target.id}'),
                            shot: shot,
                            active:
                                looking != null &&
                                shot.cameraIds.contains(looking),
                            onTap: () => _tap(shot),
                            onOpen: shot.open || onNavigate == null
                                ? null
                                : () => onNavigate!(shot.target),
                          ),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _ShotChip3d extends StatelessWidget {
  final Plan3dShot shot;

  /// Se está mirando por una de sus cámaras.
  final bool active;
  final VoidCallback onTap;

  /// Abre su planta (pulsación larga).
  final VoidCallback? onOpen;

  const _ShotChip3d({
    super.key,
    required this.shot,
    required this.active,
    required this.onTap,
    this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final here = shot.cameraIds.isNotEmpty;
    final color = active
        ? palette.accent
        : shot.open
        ? palette.textPrimary
        : here
        ? palette.textSecondary
        : palette.textTertiary;
    final tip = here
        ? '${shot.target.label}: ver por su cámara'
              '${shot.cameraIds.length > 1 ? ' (otra vez, la siguiente)' : ''}'
        : shot.open
        ? '${shot.target.label}: aún no tiene cámara'
        : '${shot.target.label}: abrir su planta';
    return Tooltip(
      message: onOpen == null || !here
          ? tip
          : '$tip · mantén pulsado para abrir su planta',
      child: Material(
        color: active
            ? palette.accent.withValues(alpha: 0.18)
            : palette.surfaceElevated,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(
            color: active || shot.open ? color : palette.border,
            width: shot.open ? 1.5 : 1,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          onLongPress: onOpen,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  here ? Icons.videocam_outlined : Icons.open_in_new,
                  size: 14,
                  color: color,
                ),
                const SizedBox(width: 4),
                Text(
                  shot.letters.isEmpty
                      ? shot.tag
                      : '${shot.tag} ${shot.letters.join()}',
                  style: AppTypography.caption(
                    palette,
                  ).copyWith(color: color, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
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
  final int? projectId;
  final ScanTopSink? onScanTop;
  final CaptureSink? onCapture;
  final ExposureSettings? exposure;
  final double? stop;
  final SetEnvironment? environment;
  final Future<void> Function(RoomSetting)? onRoom;
  final PlanTarget? navTarget;
  final ValueChanged<PlanTarget>? onNavigate;
  final bool lookThrough;

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
    this.projectId,
    this.onScanTop,
    this.onCapture,
    this.exposure,
    this.stop,
    this.environment,
    this.onRoom,
    this.navTarget,
    this.onNavigate,
    this.lookThrough = false,
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
    int? projectId,
    ScanTopSink? onScanTop,
    CaptureSink? onCapture,
    ExposureSettings? exposure,
    double? stop,
    SetEnvironment? environment,
    Future<void> Function(RoomSetting)? onRoom,
    PlanTarget? navTarget,
    ValueChanged<PlanTarget>? onNavigate,
    bool lookThrough = false,
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
        projectId: projectId,
        onScanTop: onScanTop,
        onCapture: onCapture,
        exposure: exposure,
        stop: stop,
        environment: environment,
        onRoom: onRoom,
        navTarget: navTarget,
        onNavigate: onNavigate,
        lookThrough: lookThrough,
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
      projectId: widget.projectId,
      onScanTop: widget.onScanTop,
      onCapture: widget.onCapture,
      exposure: widget.exposure,
      stop: widget.stop,
      environment: widget.environment,
      onRoom: widget.onRoom,
      navTarget: widget.navTarget,
      onNavigate: widget.onNavigate,
      lookThrough: widget.lookThrough,
    ),
  );
}
