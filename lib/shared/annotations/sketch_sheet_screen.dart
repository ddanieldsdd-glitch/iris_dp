import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:pdf_render_maintained/pdf_render_maintained.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import 'annotation_brush_catalog.dart';
import 'annotation_brushes.dart';
import 'annotation_canvas.dart';
import 'annotation_document.dart';
import 'annotation_raster.dart';
import 'annotation_tools.dart';
import 'brushes/auto_import.dart';
import 'brushes/custom_brush_store.dart';
import 'brushes/paper_library.dart';
import 'sheet/brush_studio.dart';
import 'sheet/sheet_guides.dart';
import 'sheet/sheet_panels.dart';

/// Para qué es el folio: cambia el estilo, las capas y las guías de inicio.
enum SketchSheetPurpose {
  /// Boceto de planta de luz y cámara (vista cenital, sellos).
  lightingPlan,

  /// Viñeta de storyboard (lápiz, tinta o rotulador gris).
  storyboard,
}

class SketchSheetResult {
  final AnnotationDocument document;

  /// PNG del dibujo (solo si se pidió con `exportPng`).
  final Uint8List? png;

  const SketchSheetResult({required this.document, this.png});
}

/// Qué hace el lápiz sobre el folio.
enum _Mode {
  paint,
  smudge,
  erase,
  select,
  line,
  arrow,
  path,
  text,
  stamp,
  eraseStroke,
}

enum _Panel { brushes, layers, color, actions, settings, paper }

/// Folio a pantalla completa para dibujar a mano, al estilo de Procreate:
/// pinceles con textura, capas, difumino, goma con cualquier pincel y gestos
/// para mover, girar y acercar el folio.
class SketchSheetScreen extends StatefulWidget {
  final String title;
  final AnnotationDocument initialDocument;
  final SketchSheetPurpose purpose;

  /// Ancho / alto del folio.
  final double aspectRatio;
  final bool exportPng;

  /// Viñeta anterior, para verla atenuada encima (papel cebolla). Nunca
  /// entra en el dibujo ni en el PNG exportado.
  final ImageProvider? onionSkin;

  /// De dónde es esa viñeta («Plano 1»), para la etiqueta del folio.
  final String? onionSkinLabel;

  const SketchSheetScreen({
    super.key,
    required this.title,
    required this.initialDocument,
    required this.purpose,
    required this.aspectRatio,
    this.exportPng = false,
    this.onionSkin,
    this.onionSkinLabel,
  });

  static Future<SketchSheetResult?> open(
    BuildContext context, {
    required String title,
    required AnnotationDocument document,
    required SketchSheetPurpose purpose,
    double? aspectRatio,
    bool exportPng = false,
    ImageProvider? onionSkin,
    String? onionSkinLabel,
  }) {
    return Navigator.of(context, rootNavigator: true).push<SketchSheetResult>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => SketchSheetScreen(
          title: title,
          initialDocument: document,
          purpose: purpose,
          aspectRatio:
              aspectRatio ??
              (purpose == SketchSheetPurpose.storyboard ? 16 / 9 : 1.414),
          exportPng: exportPng,
          onionSkin: onionSkin,
          onionSkinLabel: onionSkinLabel,
        ),
      ),
    );
  }

  @override
  State<SketchSheetScreen> createState() => _SketchSheetScreenState();
}

class _SketchSheetScreenState extends State<SketchSheetScreen> {
  late final AnnotationCanvasController _controller;
  late AnnotationDocument _baseline;
  late SketchStyle _style;
  bool _chooseStyle = false;

  _Mode _mode = _Mode.paint;
  _Panel? _panel;
  late String _paintBrushId;
  String _eraseBrushId = 'eraser.kneaded';
  static const _smudgeBrushId = 'smudge.stump';
  final Map<String, double> _widths = {};
  final Map<String, double> _opacities = {};
  Color _color = const Color(0xFF1A1A1A);
  final List<int> _recent = [];
  late String _activeLayerId;

  AnnotationStampKind _stampKind = AnnotationStampKind.camera;
  double _stampSize = 0.07;

  bool _guides = true;
  SheetFrame _frame = SheetFrame.none;
  bool _safeArea = false;
  PerspectiveGuide _perspective = const PerspectiveGuide();
  bool _magnet = true;
  bool _onion = CustomBrushStore.instance.onionSkinOn;
  double _onionOpacity = 0.3;
  bool _gridMagnet = false;
  double _metersPerSquare = 1;
  bool _fullFrame = false;
  bool _straighten = true;
  bool _fingerDraws = true;
  bool _stylusSeen = false;
  double _streamline = 0.2;
  bool _eyedropper = false;
  bool _saving = false;

  // Vista: zoom, giro y desplazamiento del folio.
  double _zoom = 1;

  /// Ajustando el tamaño: se enseña el diámetro real en el folio.
  bool _sizing = false;
  double _rotation = 0;
  Offset _pan = Offset.zero;
  double _rasterZoom = 1;
  double _baseZoom = 1;
  double _baseRotation = 0;
  Offset _basePan = Offset.zero;
  Offset _startFocal = Offset.zero;

  // Toques con varios dedos: deshacer (2) y rehacer (3).
  final Map<int, Offset> _touches = {};
  int _maxTouches = 0;
  DateTime? _touchStart;
  bool _touchMoved = false;
  PointerDeviceKind _lastKind = PointerDeviceKind.mouse;

  final GlobalKey _sheetKey = GlobalKey();

  bool get _storyboard => widget.purpose == SketchSheetPurpose.storyboard;

  @override
  void initState() {
    super.initState();
    _controller = AnnotationCanvasController(document: widget.initialDocument);
    final doc = widget.initialDocument;
    final fresh = doc.isEmpty && doc.layers.isEmpty;
    _style = _storyboard
        ? (_styleFromLayers(doc) ?? BrushCatalog.drawingStyle)
        : BrushCatalog.planStyle;
    if (fresh) {
      _controller.replaceDocument(
        AnnotationDocument(layers: _style.layers, paper: _style.paper),
      );
      _activeLayerId = _style.startLayerId;
      _chooseStyle = _storyboard;
    } else {
      _activeLayerId = _controller.layers.last.id;
    }
    _baseline = _controller.document;
    _selectBrush(BrushCatalog.byId(_style.shelf.first)!, notify: false);
    // Pinceles propios (importados o variantes): se cargan aparte.
    _stylusSeen = CustomBrushStore.instance.pencilSeen;
    _fingerDraws = !_stylusSeen;
    CustomBrushStore.instance.ensureLoaded().then((_) {
      if (!mounted) return;
      setState(() {
        _onion = CustomBrushStore.instance.onionSkinOn;
        // Si en este dispositivo ya se usó el Pencil, el dedo mueve.
        if (CustomBrushStore.instance.pencilSeen && !_stylusSeen) {
          _stylusSeen = true;
          _fingerDraws = false;
        }
      });
    });
    PaperLibrary.rasterizePdf ??= _pdfFirstPage;
    PaperLibrary.instance.ensureLoaded().then((_) {
      if (mounted) setState(() {});
    });
    _autoImport();
  }

  /// Lo que haya en `Documents/Importar` entra solo, en segundo plano.
  Future<void> _autoImport() async {
    final result = await AutoImport.run();
    if (!mounted || result.isEmpty) return;
    setState(() {});
    final added = result.describe();
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(
        content: Text(
          [
            if (added.isNotEmpty) 'Importado de la carpeta Importar: $added.',
            if (result.failed.isNotEmpty)
              'No se pudo leer: ${result.failed.join(', ')}.',
          ].join('\n'),
        ),
      ),
    );
  }

  /// Importa papeles desde Archivos (PNG, JPG, HEIC o PDF) o desde Fotos,
  /// y pone el último en el folio.
  Future<void> _importPapers({bool fromPhotos = false}) async {
    final picked = fromPhotos
        ? await FilePicker.platform.pickFiles(
            type: FileType.image,
            allowMultiple: true,
          )
        : await FilePicker.platform.pickFiles(
            type: FileType.custom,
            allowedExtensions: const [
              'png',
              'jpg',
              'jpeg',
              'heic',
              'heif',
              'pdf',
            ],
            allowMultiple: true,
          );
    final paths = [
      for (final f in picked?.files ?? const <PlatformFile>[])
        if (f.path != null) f.path!,
    ];
    if (paths.isEmpty || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          paths.length == 1 ? 'Preparando el papel…' : 'Preparando papeles…',
        ),
      ),
    );
    PaperTexture? last;
    final problems = <String>[];
    for (final path in paths) {
      try {
        last = await PaperLibrary.instance.importPaper(path);
      } on FormatException catch (e) {
        problems.add(e.message);
      }
    }
    if (!mounted) return;
    if (last != null) _controller.setPaperImage(last.id);
    setState(() {});
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            [
              if (last != null)
                paths.length == 1
                    ? 'Papel «${last.name}» listo.'
                    : '${paths.length - problems.length} papeles listos.',
              ...problems,
            ].join('\n'),
          ),
        ),
      );
  }

  void _setOnion(bool on) {
    setState(() => _onion = on);
    CustomBrushStore.instance.setOnionSkin(on);
  }

  /// Etiqueta del papel cebolla: se ve qué hay encima y se quita de un toque.
  Widget _buildOnionChip() {
    final label = widget.onionSkinLabel ?? 'viñeta anterior';
    return Material(
      color: _onion ? const Color(0xE62997FF) : const Color(0xCC202124),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => _setOnion(!_onion),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _onion ? Icons.layers_clear_outlined : Icons.layers_outlined,
                size: 16,
                color: Colors.white,
              ),
              const SizedBox(width: 6),
              Text(
                _onion ? 'Papel cebolla · $label  ✕' : 'Ver $label debajo',
                style: const TextStyle(color: Colors.white, fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Primera página de un PDF como PNG (para usarla de papel).
  static Future<Uint8List?> _pdfFirstPage(String path) async {
    final doc = await PdfDocument.openFile(path);
    try {
      final page = await doc.getPage(1);
      final scale = 2048 / math.max(page.width, page.height);
      final w = (page.width * scale).round();
      final h = (page.height * scale).round();
      final rendered = await page.render(
        width: w,
        height: h,
        fullWidth: w.toDouble(),
        fullHeight: h.toDouble(),
      );
      final image = await rendered.createImageDetached();
      rendered.dispose();
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      return data?.buffer.asUint8List();
    } catch (_) {
      return null;
    } finally {
      await doc.dispose();
    }
  }

  Future<void> _importPalette() async {
    final picked = await FilePicker.platform.pickFiles(type: FileType.any);
    final path = picked?.files.singleOrNull?.path;
    if (path == null || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final added = await PaperLibrary.instance.importSwatches(path);
      if (!mounted) return;
      setState(() {});
      messenger.showSnackBar(
        SnackBar(content: Text('Paleta «${added.first.name}» añadida.')),
      );
    } on FormatException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _deletePaper(PaperTexture paper) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('¿Quitar el papel «${paper.name}»?'),
        content: const Text(
          'Los dibujos que lo usan se verán sobre papel marfil en este '
          'dispositivo hasta que lo vuelvas a importar.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Quitar'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await PaperLibrary.instance.deletePaper(paper.id);
    if (mounted) setState(() {});
  }

  Future<void> _importBrushes() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.any,
      allowMultiple: true,
    );
    final files = picked?.files ?? const <PlatformFile>[];
    if (files.isEmpty || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      const SnackBar(content: Text('Importando pinceles…')),
    );
    final added = <BrushSpec>[];
    final problems = <String>[];
    for (final file in files) {
      try {
        final path = file.path;
        final bytes = file.bytes;
        added.addAll(
          path != null
              ? await CustomBrushStore.instance.importProcreateFile(path)
              : bytes != null
              ? await CustomBrushStore.instance.importProcreate(
                  bytes,
                  fileName: file.name,
                )
              : const [],
        );
      } on FormatException catch (e) {
        problems.add('${file.name}: ${e.message}');
      }
    }
    if (!mounted) return;
    setState(() {});
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            [
              if (added.isNotEmpty)
                added.length == 1
                    ? 'Pincel «${added.single.name}» importado en «Míos».'
                    : '${added.length} pinceles importados en «Míos».',
              ...problems,
            ].join('\n'),
          ),
        ),
      );
  }

  Future<void> _tuneBrush(BrushSpec brush) async {
    final result = await showBrushStudio(
      context,
      base: brush,
      color: _color,
      paper: _controller.document.paper ?? AnnotationPaper.white,
    );
    if (result == null || !mounted) return;
    final saved = await CustomBrushStore.instance.saveVariant(
      brush,
      name: result.name,
      params: result.params,
      color: _color.toARGB32(),
    );
    if (saved == null || !mounted) return;
    _selectBrush(saved);
  }

  Future<void> _deleteBrush(BrushSpec brush) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('¿Quitar «${brush.name}»?'),
        content: const Text(
          'Lo que ya dibujaste con él se seguirá viendo, pintado con un '
          'pincel parecido.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Quitar'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    if (_paintBrushId == brush.id) {
      _paintBrushId = _style.shelf.first;
    }
    if (_eraseBrushId == brush.id) _eraseBrushId = 'eraser.kneaded';
    await CustomBrushStore.instance.delete(brush.id);
    if (mounted) setState(() {});
  }

  static SketchStyle? _styleFromLayers(AnnotationDocument doc) {
    final ids = doc.layers.map((l) => l.id).toSet();
    if (ids.isEmpty) return null;
    for (final style in [...BrushCatalog.styles, ...BrushCatalog.legacyStyles]) {
      if (style.layers.every((l) => ids.contains(l.id))) return style;
    }
    return null;
  }

  @override
  void dispose() {
    _sizingOff?.cancel();
    _controller.dispose();
    super.dispose();
  }

  bool get _dirty => _controller.document != _baseline;

  // ─── Pincel, tamaño y opacidad ─────────────────────────────────────────────

  String get _brushId => switch (_mode) {
    _Mode.smudge => _smudgeBrushId,
    _Mode.erase => _eraseBrushId,
    _ => _paintBrushId,
  };

  BrushSpec get _brush => BrushCatalog.byId(_brushId)!;

  String get _key => '${_mode.name}:$_brushId';

  double get _width => _widths[_key] ?? _brush.defaultWidth;

  double get _opacity => _opacities[_key] ?? _brush.defaultOpacity;

  bool get _brushMode =>
      _mode == _Mode.paint || _mode == _Mode.smudge || _mode == _Mode.erase;

  void _selectBrush(BrushSpec brush, {bool notify = true}) {
    void apply() {
      if (_mode == _Mode.erase) {
        _eraseBrushId = brush.id;
        return;
      }
      _paintBrushId = brush.id;
      _mode = _Mode.paint;
      // Cada pincel trae su color (sanguina, gris del rotulador…).
      _color = Color(brush.defaultColor);
    }

    if (notify) {
      setState(apply);
    } else {
      apply();
    }
  }

  AnnotationToolType get _canvasTool => switch (_mode) {
    _Mode.paint => _brush.family,
    _Mode.smudge => AnnotationToolType.airbrush,
    _Mode.erase => AnnotationToolType.eraseArea,
    _Mode.select => AnnotationToolType.select,
    _Mode.line => AnnotationToolType.line,
    _Mode.arrow || _Mode.path => AnnotationToolType.arrow,
    _Mode.text => AnnotationToolType.text,
    _Mode.stamp => AnnotationToolType.stamp,
    _Mode.eraseStroke => AnnotationToolType.eraser,
  };

  String? get _canvasBrushId => switch (_mode) {
    _Mode.paint || _Mode.smudge || _Mode.erase => _brushId,
    // La recta se pinta con el pincel elegido si es de trazo.
    _Mode.line =>
      BrushCatalog.byId(_paintBrushId)!.isArea ? null : _paintBrushId,
    _Mode.path => AnnotationBrushes.pathArrowId,
    _ => null,
  };

  String get _widthKey => _mode == _Mode.line ? 'paint:$_paintBrushId' : _key;

  double get _canvasWidth => switch (_mode) {
    _Mode.line =>
      _widths[_widthKey] ?? BrushCatalog.byId(_paintBrushId)!.defaultWidth,
    _Mode.arrow || _Mode.path => 4,
    _ => _width,
  };

  /// Capa en la que cae lo nuevo. En la planta, cada sello va a la suya.
  String get _targetLayerId {
    if (_style.id == BrushCatalog.planStyle.id) {
      final wanted = switch (_mode) {
        _Mode.stamp => switch (_stampKind) {
          AnnotationStampKind.camera ||
          AnnotationStampKind.dolly ||
          AnnotationStampKind.crane => 'camaras',
          AnnotationStampKind.actor => 'personajes',
          AnnotationStampKind.text => 'notas',
          AnnotationStampKind.window ||
          AnnotationStampKind.door ||
          AnnotationStampKind.table ||
          AnnotationStampKind.chair ||
          AnnotationStampKind.sofa ||
          AnnotationStampKind.car => 'decorado',
          _ => 'luz',
        },
        _Mode.text => 'notas',
        _Mode.path => 'camaras',
        _ => null,
      };
      if (wanted != null && _controller.layerById(wanted) != null) {
        return wanted;
      }
    }
    return _controller.layerById(_activeLayerId) != null
        ? _activeLayerId
        : _controller.layers.last.id;
  }

  bool get _layerBlocked {
    if (_mode == _Mode.select || _mode == _Mode.eraseStroke) return false;
    final layer = _controller.layerById(_targetLayerId);
    return layer == null || !layer.visible || layer.locked;
  }

  // ─── Acciones ──────────────────────────────────────────────────────────────

  void _applyStyle(SketchStyle style) {
    setState(() {
      _style = style;
      _chooseStyle = false;
      if (_controller.document.isEmpty) {
        _controller.replaceDocument(
          AnnotationDocument(layers: style.layers, paper: style.paper),
        );
        _baseline = _controller.document;
      } else {
        _controller.applyLayout(style.layers, style.paper);
      }
      _activeLayerId = _controller.layerById(style.startLayerId) != null
          ? style.startLayerId
          : _controller.layers.last.id;
      _mode = _Mode.paint;
      _selectBrush(BrushCatalog.byId(style.shelf.first)!, notify: false);
    });
  }

  void _setColor(Color color) {
    setState(() {
      _color = color;
      final argb = color.toARGB32();
      _recent
        ..remove(argb)
        ..insert(0, argb);
      if (_recent.length > 10) _recent.removeLast();
    });
    final selected = _controller.selectedStamp;
    if (_mode == _Mode.select && selected != null) {
      _controller.updateStamp(selected.id, colorArgb: color.toARGB32());
    }
  }

  void _togglePanel(_Panel panel) =>
      setState(() => _panel = _panel == panel ? null : panel);

  /// Pincel, Difuminar y Borrar: un toque elige el modo; otro abre la
  /// biblioteca (como en Procreate).
  void _tapBrushMode(_Mode mode) {
    setState(() {
      _eyedropper = false;
      if (_mode == mode && mode != _Mode.smudge) {
        _panel = _panel == _Panel.brushes ? null : _Panel.brushes;
        if (_panel == _Panel.brushes) _autoImport();
      } else {
        _mode = mode;
        if (_panel == _Panel.brushes) _panel = null;
      }
    });
  }

  void _setTool(_Mode mode) => setState(() {
    _mode = mode;
    _eyedropper = false;
    _panel = null;
  });

  Future<void> _close() async {
    if (!_dirty) {
      Navigator.of(context).pop();
      return;
    }
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Salir sin guardar?'),
        content: const Text('Se perderá lo que has dibujado en esta sesión.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Seguir dibujando'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Descartar'),
          ),
        ],
      ),
    );
    if (discard == true && mounted) Navigator.of(context).pop();
  }

  Future<void> _done() async {
    if (_saving) return;
    setState(() => _saving = true);
    final document = _controller.document;
    Uint8List? png;
    try {
      if (widget.exportPng) {
        const width = 1920.0;
        png = await AnnotationRaster.toPng(
          document,
          size: Size(width, (width / widget.aspectRatio).roundToDouble()),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
    if (!mounted) return;
    Navigator.of(context).pop(SketchSheetResult(document: document, png: png));
  }

  Future<String?> _askText({String? initial, String title = 'Texto'}) async {
    final controller = TextEditingController(text: initial);
    final text = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 3,
          minLines: 1,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(
            hintText: 'p. ej. 18K DESDE VENTANA',
          ),
          onSubmitted: (value) => Navigator.pop(context, value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Aceptar'),
          ),
        ],
      ),
    );
    controller.dispose();
    return text;
  }

  Future<void> _nameStamp(AnnotationStamp stamp) async {
    final text = await _askText(
      initial: stamp.label,
      title: 'Nombre · ${AnnotationTools.stampLabel(stamp.kind)}',
    );
    if (text == null) return;
    _controller.updateStamp(stamp.id, label: text.trim());
  }

  void _deleteSelected() {
    if (_controller.selectionCount > 1 ||
        _controller.selectedStrokeIds.isNotEmpty) {
      _controller.deleteSelection();
      return;
    }
    final selected = _controller.selectedStamp;
    if (selected != null) _controller.removeStamp(selected.id);
  }

  /// Cuentagotas: lee el color del folio ya pintado.
  Future<void> _pickColorAt(Offset local) async {
    final boundary =
        _sheetKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) return;
    final image = await boundary.toImage();
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (data == null) return;
      final x = local.dx.round().clamp(0, image.width - 1);
      final y = local.dy.round().clamp(0, image.height - 1);
      final i = (y * image.width + x) * 4;
      final bytes = data.buffer.asUint8List();
      final alpha = bytes[i + 3];
      // Donde no hay pintura se coge el papel.
      final paper = _controller.document.paper;
      final picked = alpha < 8
          ? (paper == null ? Colors.white : BrushCatalog.paperColor(paper))
          : Color.fromARGB(255, bytes[i], bytes[i + 1], bytes[i + 2]);
      _setColor(picked);
      if (mounted) setState(() => _eyedropper = false);
    } finally {
      image.dispose();
    }
  }

  static String _formatMeters(double m) =>
      m == m.roundToDouble() ? '${m.round()} m' : '${m.toStringAsFixed(1)} m';

  /// Óptica de la cámara seleccionada: su ángulo de visión se calcula con el
  /// ancho del sensor (Super 35 o full frame).
  void _setLens(AnnotationStamp stamp, double mm) {
    _controller.updateStamp(
      stamp.id,
      lensMm: mm,
      spread: AnnotationBrushes.fieldOfView(
        mm,
        sensorWidthMm: _fullFrame ? 36 : 24.9,
      ),
    );
  }

  // ─── Gestos de varios dedos ────────────────────────────────────────────────

  void _onAnyPointerDown(PointerDownEvent event) {
    _lastKind = event.kind;
    if (_panel != null) setState(() => _panel = null);
    if (event.kind == PointerDeviceKind.stylus ||
        event.kind == PointerDeviceKind.invertedStylus) {
      // Con Apple Pencil, el dedo pasa a mover el folio (se puede cambiar
      // en Ajustes).
      if (!_stylusSeen) {
        setState(() {
          _stylusSeen = true;
          _fingerDraws = false;
        });
        CustomBrushStore.instance.markPencilSeen();
      }
      return;
    }
    if (event.kind != PointerDeviceKind.touch) return;
    if (_touches.isEmpty) {
      _touchStart = DateTime.now();
      _touchMoved = false;
      _maxTouches = 0;
    }
    _touches[event.pointer] = event.position;
    _maxTouches = math.max(_maxTouches, _touches.length);
    if (_touches.length >= 2) _controller.cancelLiveStroke();
  }

  void _onAnyPointerMove(PointerMoveEvent event) {
    final start = _touches[event.pointer];
    if (start != null && (event.position - start).distance > 12) {
      _touchMoved = true;
    }
  }

  void _onAnyPointerUp(PointerEvent event) {
    if (_touches.remove(event.pointer) == null || _touches.isNotEmpty) return;
    final started = _touchStart;
    if (started == null || _touchMoved) return;
    final quick =
        DateTime.now().difference(started) < const Duration(milliseconds: 350);
    if (!quick) return;
    if (_maxTouches == 2) _controller.undo();
    if (_maxTouches == 3) _controller.redo();
  }

  bool _navigates(ScaleUpdateDetails details) =>
      details.pointerCount >= 2 ||
      (_lastKind == PointerDeviceKind.touch && !_fingerDraws);

  void _onScaleStart(ScaleStartDetails details) {
    _baseZoom = _zoom;
    _baseRotation = _rotation;
    _basePan = _pan;
    _startFocal = details.focalPoint;
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    if (!_navigates(details)) return;
    setState(() {
      _zoom = (_baseZoom * details.scale).clamp(0.4, 8.0);
      if (details.pointerCount >= 2) {
        var rotation = _baseRotation + details.rotation;
        // Cerca de recto, se queda recto.
        if (rotation.abs() < 0.12) rotation = 0;
        _rotation = rotation;
      }
      _pan = _basePan + (details.focalPoint - _startFocal);
    });
  }

  void _onScaleEnd(ScaleEndDetails details) {
    // Al acercar, las capas se rasterizan con más detalle (por pasos, para
    // no rehacerlas en cada fotograma del pellizco).
    final next = _zoom <= 1.25
        ? 1.0
        : _zoom <= 2.25
        ? 2.0
        : _zoom <= 3.5
        ? 3.0
        : 4.0;
    if (next != _rasterZoom) setState(() => _rasterZoom = next);
  }

  void _resetView() => setState(() {
    _zoom = 1;
    _rotation = 0;
    _pan = Offset.zero;
    _rasterZoom = 1;
  });

  // ─── Construcción ──────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyZ, meta: true):
            _controller.undo,
        const SingleActivator(LogicalKeyboardKey.keyZ, control: true):
            _controller.undo,
        const SingleActivator(LogicalKeyboardKey.keyZ, meta: true, shift: true):
            _controller.redo,
        const SingleActivator(
          LogicalKeyboardKey.keyZ,
          control: true,
          shift: true,
        ): _controller.redo,
        const SingleActivator(LogicalKeyboardKey.backspace): _deleteSelected,
        const SingleActivator(LogicalKeyboardKey.delete): _deleteSelected,
        const SingleActivator(LogicalKeyboardKey.keyB): () =>
            _setTool(_Mode.paint),
        const SingleActivator(LogicalKeyboardKey.keyE): () =>
            _setTool(_Mode.erase),
        const SingleActivator(LogicalKeyboardKey.keyS): () =>
            _setTool(_Mode.smudge),
      },
      child: Focus(
        autofocus: true,
        child: ListenableBuilder(
          listenable: _controller,
          builder: (context, _) => PopScope(
            canPop: !_dirty,
            onPopInvokedWithResult: (didPop, _) {
              if (!didPop) _close();
            },
            child: Scaffold(
              backgroundColor: const Color(0xFF2A2B2E),
              body: SafeArea(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildTopBar(palette),
                    Expanded(
                      child: Stack(
                        children: [
                          Positioned.fill(child: _buildWorkspace()),
                          if (_sizing)
                            Positioned.fill(
                              child: IgnorePointer(
                                child: Center(
                                  child: _SizePreview(
                                    diameter: _screenDiameter(),
                                    label: _sizeLabel(_canvasWidth),
                                    color: _color,
                                  ),
                                ),
                              ),
                            ),
                          Positioned(
                            left: 10,
                            top: 0,
                            bottom: 0,
                            child: Center(child: _buildSideBar()),
                          ),
                          if (_panel != null)
                            Positioned(
                              right: 12,
                              top: 8,
                              bottom: 12,
                              child: Align(
                                alignment: Alignment.topRight,
                                child: _buildPanel(_panel!),
                              ),
                            ),
                          if (_panel == null &&
                              (_mode == _Mode.stamp ||
                                  _mode == _Mode.select ||
                                  _mode == _Mode.text ||
                                  _mode == _Mode.path))
                            Positioned(
                              right: 12,
                              bottom: 12,
                              child: _buildToolOptions(palette),
                            ),
                          if (_chooseStyle && _controller.document.isEmpty)
                            Positioned(
                              left: 0,
                              right: 0,
                              bottom: 16,
                              child: Center(child: _buildStyleChooser()),
                            ),
                          if (widget.onionSkin != null)
                            Positioned(
                              left: 76,
                              top: 10,
                              child: _buildOnionChip(),
                            ),
                          if (_layerBlocked)
                            Positioned(
                              top: 10,
                              left: 0,
                              right: 0,
                              child: Center(
                                child: _Banner(
                                  text:
                                      _controller
                                              .layerById(_targetLayerId)
                                              ?.locked ==
                                          true
                                      ? 'La capa está bloqueada'
                                      : 'La capa está oculta: muéstrala '
                                            'para dibujar',
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(AppPalette palette) {
    Widget sep() => Container(
      width: 1,
      height: 24,
      margin: const EdgeInsets.symmetric(horizontal: 6),
      color: Colors.white12,
    );
    return Container(
      height: 52,
      color: const Color(0xFF1E1F21),
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Cerrar',
            color: Colors.white70,
            icon: const Icon(Icons.close),
            onPressed: _close,
          ),
          Flexible(
            child: Text(
              widget.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.titleMedium(
                palette,
              ).copyWith(color: Colors.white),
            ),
          ),
          const SizedBox(width: 6),
          _TopButton(
            tooltip: 'Acciones',
            icon: Icons.build_outlined,
            selected: _panel == _Panel.actions,
            onTap: () => _togglePanel(_Panel.actions),
          ),
          _TopButton(
            tooltip: 'Ajustes',
            icon: Icons.tune,
            selected: _panel == _Panel.settings,
            onTap: () => _togglePanel(_Panel.settings),
          ),
          sep(),
          for (final (mode, label, icon) in const [
            (_Mode.select, 'Mover', Icons.open_with),
            (_Mode.line, 'Recta', Icons.horizontal_rule),
            (_Mode.arrow, 'Flecha', Icons.north_east),
            (_Mode.path, 'Recorrido', Icons.route_outlined),
            (_Mode.text, 'Texto', Icons.title),
            (_Mode.stamp, 'Sellos', Icons.videocam_outlined),
            (_Mode.eraseStroke, 'Borrar trazo', Icons.auto_fix_off),
          ])
            _TopButton(
              tooltip: label,
              icon: icon,
              selected: _mode == mode,
              onTap: () => _setTool(mode),
            ),
          const Spacer(),
          _TopButton(
            tooltip: 'Pincel',
            icon: Icons.brush_outlined,
            selected: _mode == _Mode.paint,
            onTap: () => _tapBrushMode(_Mode.paint),
          ),
          _TopButton(
            tooltip: 'Difuminar',
            icon: Icons.touch_app_outlined,
            selected: _mode == _Mode.smudge,
            onTap: () => _tapBrushMode(_Mode.smudge),
          ),
          _TopButton(
            tooltip: 'Borrar',
            icon: Icons.cleaning_services_outlined,
            selected: _mode == _Mode.erase,
            onTap: () => _tapBrushMode(_Mode.erase),
          ),
          _TopButton(
            tooltip: 'Capas',
            icon: Icons.layers_outlined,
            selected: _panel == _Panel.layers,
            onTap: () => _togglePanel(_Panel.layers),
          ),
          Tooltip(
            message: 'Color',
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () => _togglePanel(_Panel.color),
              child: Container(
                width: 30,
                height: 30,
                margin: const EdgeInsets.symmetric(horizontal: 6),
                decoration: BoxDecoration(
                  color: _color,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white70, width: 2),
                ),
              ),
            ),
          ),
          sep(),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 9),
            child: FilledButton.icon(
              onPressed: _saving ? null : _done,
              icon: _saving
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check, size: 18),
              label: const Text('Hecho'),
            ),
          ),
          const SizedBox(width: 6),
        ],
      ),
    );
  }

  static String _sizeLabel(double width) =>
      width < 10 ? width.toStringAsFixed(1) : '${width.round()}';

  /// Diámetro del pincel en pantalla, como lo pintará en el folio (con el
  /// zoom de ahora).
  double _screenDiameter() {
    final sheet = _sheetKey.currentContext?.size;
    final spec = _mode == _Mode.line
        ? BrushCatalog.byId(_paintBrushId)
        : BrushCatalog.byId(_brushId);
    final unit = sheet == null
        ? 1.0
        : math.min(sheet.width, sheet.height) / 1000;
    return _canvasWidth * unit * (spec?.sizeScale ?? 1) * _zoom;
  }

  /// Un paso fino de tamaño: más fino cuanto más fino el pincel.
  void _stepSize(double width, int direction) {
    final step = width < 2
        ? 0.1
        : width < 10
        ? 0.5
        : width < 50
        ? 1.0
        : 5.0;
    setState(() {
      _widths[_widthKey] = (width + step * direction).clamp(0.5, 300.0);
      _sizing = true;
    });
    _sizingOff?.cancel();
    _sizingOff = Timer(const Duration(milliseconds: 900), () {
      if (mounted) setState(() => _sizing = false);
    });
  }

  Timer? _sizingOff;

  /// Escribir el tamaño exacto.
  Future<void> _typeSize(double width) async {
    final controller = TextEditingController(text: _sizeLabel(width));
    final value = await showDialog<double>(
      context: context,
      builder: (ctx) {
        void submit() {
          final v = double.tryParse(controller.text.replaceAll(',', '.'));
          if (v != null && v > 0) Navigator.pop(ctx, v);
        }

        return AlertDialog(
          title: const Text('Tamaño del pincel'),
          content: TextField(
            controller: controller,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(helperText: 'De 0,5 a 300'),
            onSubmitted: (_) => submit(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            TextButton(onPressed: submit, child: const Text('Aplicar')),
          ],
        );
      },
    );
    controller.dispose();
    if (value == null || !mounted) return;
    setState(() => _widths[_widthKey] = value.clamp(0.5, 300.0));
  }

  Widget _buildSideBar() {
    final sizeEditable = _brushMode || _mode == _Mode.line;
    final width = _canvasWidth;
    return Container(
      width: 48,
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xEB1E1F21),
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 10)],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _VerticalSlider(
            tooltip: 'Tamaño',
            // Escala exponencial: precisión en los grosores finos.
            value: sizeEditable
                ? (math.log(width / 0.5) / math.log(600)).clamp(0.0, 1.0)
                : 0,
            enabled: sizeEditable,
            label: _sizeLabel(width),
            onChanged: (t) => setState(
              () => _widths[_widthKey] = 0.5 * math.pow(600, t).toDouble(),
            ),
            onChangeStart: (_) => setState(() => _sizing = true),
            onChangeEnd: (_) => setState(() => _sizing = false),
            onStep: sizeEditable ? (dir) => _stepSize(width, dir) : null,
            onLabelTap: sizeEditable ? () => _typeSize(width) : null,
          ),
          const SizedBox(height: 4),
          IconButton(
            tooltip: 'Cuentagotas',
            color: Colors.white70,
            isSelected: _eyedropper,
            icon: const Icon(Icons.colorize, size: 20),
            onPressed: () => setState(() => _eyedropper = !_eyedropper),
          ),
          const SizedBox(height: 4),
          _VerticalSlider(
            tooltip: 'Opacidad',
            value: _brushMode ? _opacity : 1,
            enabled: _brushMode,
            label: '${(_opacity * 100).round()}',
            onChanged: (v) =>
                setState(() => _opacities[_key] = v.clamp(0.05, 1.0)),
          ),
          const SizedBox(height: 6),
          IconButton(
            tooltip: 'Deshacer (⌘Z)',
            color: Colors.white70,
            onPressed: _controller.canUndo ? _controller.undo : null,
            icon: const Icon(Icons.undo, size: 20),
          ),
          IconButton(
            tooltip: 'Rehacer (⇧⌘Z)',
            color: Colors.white70,
            onPressed: _controller.canRedo ? _controller.redo : null,
            icon: const Icon(Icons.redo, size: 20),
          ),
          if (_zoom != 1 || _rotation != 0 || _pan != Offset.zero)
            IconButton(
              tooltip: 'Ajustar al folio',
              color: Colors.white70,
              onPressed: _resetView,
              icon: const Icon(Icons.fit_screen_outlined, size: 20),
            ),
        ],
      ),
    );
  }

  Widget _buildWorkspace() {
    final layer = _controller.layerById(_targetLayerId);
    final canvas = AnnotationCanvas(
      controller: _controller,
      enabled: !_saving && !_eyedropper && !_layerBlocked,
      tool: _canvasTool,
      brushId: _canvasBrushId,
      layerId: _targetLayerId,
      alphaLocked: _mode == _Mode.paint && (layer?.alphaLock ?? false),
      color: _color,
      width: _canvasWidth,
      opacity: _brushMode ? _opacity : 1,
      stampKind: _stampKind,
      stampSize: _stampSize,
      acceptTouch: _fingerDraws,
      straightenOnHold: _straighten,
      streamline: _mode == _Mode.paint
          ? math.max(_streamline, _brush.streamline)
          : 0,
      resolutionScale: _rasterZoom,
      lineSnap: _magnet && _perspective.enabled ? _perspective.snap : null,
      gridStep: !_storyboard && _guides && _gridMagnet ? 1 / 16 : null,
      onTextRequested: () => _askText(),
      onStampEditRequested: _nameStamp,
    );
    final paper = _controller.document.paper;
    final sheet = AspectRatio(
      aspectRatio: widget.aspectRatio,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: paper == null ? Colors.white : BrushCatalog.paperColor(paper),
          boxShadow: const [
            BoxShadow(
              color: Colors.black54,
              blurRadius: 22,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: ClipRect(
          child: Stack(
            fit: StackFit.expand,
            children: [
              RepaintBoundary(key: _sheetKey, child: canvas),
              if (widget.onionSkin != null && _onion)
                IgnorePointer(
                  child: Opacity(
                    opacity: _onionOpacity,
                    child: Image(image: widget.onionSkin!, fit: BoxFit.fill),
                  ),
                ),
              if (_guides)
                IgnorePointer(
                  child: CustomPaint(
                    painter: _GuidesPainter(thirds: _storyboard),
                  ),
                ),
              if (!_storyboard && _guides)
                Positioned(
                  left: 8,
                  bottom: 6,
                  child: IgnorePointer(
                    child: Text(
                      '1 cuadro = ${_formatMeters(_metersPerSquare)}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0x992997FF),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              if (_frame != SheetFrame.none || _safeArea)
                IgnorePointer(
                  child: CustomPaint(
                    painter: FrameGuidePainter(
                      frame: _frame,
                      safeArea: _safeArea,
                    ),
                  ),
                ),
              if (_perspective.enabled) ...[
                IgnorePointer(
                  child: CustomPaint(painter: PerspectivePainter(_perspective)),
                ),
                LayoutBuilder(
                  builder: (context, box) {
                    final size = Size(box.maxWidth, box.maxHeight);
                    return Stack(
                      children: [
                        VanishingPointHandle(
                          tooltip: 'Punto de fuga',
                          position: _perspective.vp1,
                          sheet: size,
                          onMoved: (p) => setState(
                            () => _perspective = _perspective.copyWith(vp1: p),
                          ),
                        ),
                        if (_perspective.points == 2)
                          VanishingPointHandle(
                            tooltip: 'Segundo punto de fuga',
                            position: _perspective.vp2,
                            sheet: size,
                            onMoved: (p) => setState(
                              () =>
                                  _perspective = _perspective.copyWith(vp2: p),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ],
              if (_eyedropper)
                Positioned.fill(
                  child: MouseRegion(
                    cursor: SystemMouseCursors.precise,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTapUp: (d) => _pickColorAt(d.localPosition),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _onAnyPointerDown,
      onPointerMove: _onAnyPointerMove,
      onPointerUp: _onAnyPointerUp,
      onPointerCancel: _onAnyPointerUp,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onScaleStart: _onScaleStart,
        onScaleUpdate: _onScaleUpdate,
        onScaleEnd: _onScaleEnd,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(76, 18, 24, 24),
          child: Center(
            child: Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..translateByDouble(_pan.dx, _pan.dy, 0, 1)
                ..rotateZ(_rotation)
                ..scaleByDouble(_zoom, _zoom, 1, 1),
              child: sheet,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPanel(_Panel panel) {
    final paper = _controller.document.paper ?? AnnotationPaper.white;
    switch (panel) {
      case _Panel.brushes:
        final erase = _mode == _Mode.erase;
        return BrushLibraryPanel(
          title: erase ? 'Borrar con…' : 'Pinceles',
          selectedId: _brushId,
          store: CustomBrushStore.instance,
          color: _color,
          paper: paper,
          filter: (brush) => erase
              ? !brush.isArea && brush.mode != BrushMode.smudge
              : brush.mode == BrushMode.paint,
          onSelect: (brush) {
            _selectBrush(brush);
            setState(() => _panel = null);
          },
          onImport: _importBrushes,
          onTune: erase ? null : _tuneBrush,
          onDelete: _deleteBrush,
          favorites: CustomBrushStore.instance.favorites,
          onToggleFavorite: (brush) async {
            await CustomBrushStore.instance.toggleFavorite(brush.id);
            if (mounted) setState(() {});
          },
        );
      case _Panel.layers:
        return LayersPanel(
          controller: _controller,
          activeLayerId: _targetLayerId,
          onActivate: (id) => setState(() => _activeLayerId = id),
        );
      case _Panel.color:
        return ColorPanel(
          color: _color,
          styleColors: _style.palette,
          recent: _recent,
          onChanged: _setColor,
          palettes: [for (final p in PaperLibrary.palettes) (p.name, p.colors)],
          onImportPalette: _importPalette,
        );
      case _Panel.actions:
        return _buildActions();
      case _Panel.settings:
        return _buildSettings();
      case _Panel.paper:
        return _buildPaperPanel();
    }
  }

  Widget _buildActions() {
    final palette = context.palette;
    final doc = _controller.document;
    // Dos estilos: dibujo y planta (en la planta, primero la planta).
    final styles = _storyboard
        ? BrushCatalog.styles
        : BrushCatalog.styles.reversed.toList();
    return SheetPanel(
      title: 'Acciones',
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        children: [
          Text('Estilo', style: AppTypography.label(palette)),
          for (final style in styles)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              selected: style.id == _style.id,
              title: Text(style.name),
              subtitle: Text(style.description),
              onTap: () {
                _applyStyle(style);
                setState(() => _panel = null);
              },
            ),
          const SizedBox(height: 8),
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.texture),
            title: const Text('Papel'),
            subtitle: Text(
              PaperLibrary.paper(doc.paperImage)?.name ??
                  BrushCatalog.paperLabel(doc.paper ?? AnnotationPaper.white),
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => setState(() => _panel = _Panel.paper),
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Text(_storyboard ? 'Guías de tercios' : 'Cuadrícula'),
            value: _guides,
            onChanged: (v) => setState(() => _guides = v),
          ),
          if (!_storyboard && _guides) ...[
            SwitchListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: const Text('Imán de rejilla'),
              subtitle: const Text('Los sellos caen en los cruces.'),
              value: _gridMagnet,
              onChanged: (v) => setState(() => _gridMagnet = v),
            ),
            Text('Escala', style: AppTypography.label(palette)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              children: [
                for (final m in const [0.5, 1.0, 2.0])
                  ChoiceChip(
                    label: Text('1 cuadro = ${_formatMeters(m)}'),
                    selected: _metersPerSquare == m,
                    onSelected: (_) => setState(() => _metersPerSquare = m),
                  ),
              ],
            ),
            const SizedBox(height: 8),
          ],
          if (_storyboard) ...[
            Text('Encuadre', style: AppTypography.label(palette)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final frame in SheetFrame.values)
                  ChoiceChip(
                    label: Text(frame.label),
                    selected: _frame == frame,
                    onSelected: (_) => setState(() => _frame = frame),
                  ),
              ],
            ),
            SwitchListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: const Text('Zona segura'),
              value: _safeArea,
              onChanged: (v) => setState(() => _safeArea = v),
            ),
          ],
          Text('Perspectiva', style: AppTypography.label(palette)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            children: [
              for (final (points, label) in const [
                (0, 'Sin guía'),
                (1, '1 punto'),
                (2, '2 puntos'),
              ])
                ChoiceChip(
                  label: Text(label),
                  selected: _perspective.points == points,
                  onSelected: (_) => setState(
                    () => _perspective = points == 2
                        ? _perspective.copyWith(
                            points: 2,
                            vp1: const Offset(0.08, 0.42),
                            vp2: const Offset(0.92, 0.42),
                          )
                        : _perspective.copyWith(
                            points: points,
                            vp1: const Offset(0.5, 0.42),
                          ),
                  ),
                ),
            ],
          ),
          if (_perspective.enabled)
            SwitchListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: const Text('Imán de perspectiva'),
              subtitle: const Text(
                'Las rectas se ajustan a los puntos de fuga y a la vertical.',
              ),
              value: _magnet,
              onChanged: (v) => setState(() => _magnet = v),
            ),
          if (widget.onionSkin != null) ...[
            SwitchListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: const Text('Papel cebolla'),
              subtitle: const Text('La viñeta anterior, atenuada encima.'),
              value: _onion,
              onChanged: _setOnion,
            ),
            if (_onion)
              Slider(
                value: _onionOpacity,
                min: 0.1,
                max: 0.7,
                onChanged: (v) => setState(() => _onionOpacity = v),
              ),
          ],
          const SizedBox(height: 4),
          OutlinedButton.icon(
            onPressed: doc.isEmpty ? null : _controller.clear,
            icon: const Icon(Icons.delete_sweep_outlined, size: 18),
            label: const Text('Vaciar folio'),
          ),
        ],
      ),
    );
  }

  final Set<String> _closedPaperGroups = {};

  Widget _buildPaperPanel() {
    final palette = context.palette;
    final doc = _controller.document;
    Widget header(String id, String title, {IconData? icon}) {
      final open = !_closedPaperGroups.contains(id);
      return InkWell(
        onTap: () => setState(() {
          if (open) {
            _closedPaperGroups.add(id);
          } else {
            _closedPaperGroups.remove(id);
          }
        }),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(0, 10, 0, 6),
          child: Row(
            children: [
              Icon(
                open ? Icons.expand_more : Icons.chevron_right,
                size: 18,
                color: palette.textSecondary,
              ),
              if (icon != null)
                Icon(icon, size: 16, color: const Color(0xFFFFC107)),
              const SizedBox(width: 4),
              Text(title, style: AppTypography.label(palette)),
            ],
          ),
        ),
      );
    }

    Widget tile({
      required String name,
      required bool selected,
      required Widget image,
      required VoidCallback onTap,
      VoidCallback? onLongPress,
      bool? favorite,
      VoidCallback? onFavorite,
    }) {
      return SizedBox(
        width: 92,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                InkWell(
                  onTap: onTap,
                  onLongPress: onLongPress,
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    width: 92,
                    height: 66,
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: selected ? palette.accent : Colors.white24,
                        width: selected ? 2.5 : 1,
                      ),
                    ),
                    child: image,
                  ),
                ),
                if (favorite != null)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: IconButton(
                      tooltip: favorite
                          ? 'Quitar de favoritos'
                          : 'Añadir a favoritos',
                      visualDensity: VisualDensity.compact,
                      iconSize: 18,
                      color: favorite
                          ? const Color(0xFFFFC107)
                          : Colors.black54,
                      icon: Icon(
                        favorite
                            ? Icons.star_rounded
                            : Icons.star_border_rounded,
                      ),
                      onPressed: onFavorite,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 3),
            Text(
              name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.caption(palette),
            ),
          ],
        ),
      );
    }

    Widget paperTile(PaperTexture paper) => tile(
      name: paper.name,
      selected: doc.paperImage == paper.id,
      image: RawImage(image: paper.background, fit: BoxFit.cover),
      onTap: () => _controller.setPaperImage(paper.id),
      onLongPress: () => _paperMenu(paper),
      favorite: paper.favorite,
      onFavorite: () async {
        await PaperLibrary.instance.toggleFavorite(paper.id);
        if (mounted) setState(() {});
      },
    );

    Widget grid(List<Widget> tiles) =>
        Wrap(spacing: 8, runSpacing: 8, children: tiles);

    final favorites = PaperLibrary.papers.where((p) => p.favorite).toList();
    final groups = PaperLibrary.groups;
    return SheetPanel(
      title: 'Papel',
      actions: [
        IconButton(
          tooltip: 'Importar desde Archivos (PNG, JPG, HEIC, PDF)',
          icon: const Icon(Icons.folder_open_outlined),
          onPressed: () => _importPapers(),
        ),
        IconButton(
          tooltip: 'Importar desde Fotos',
          icon: const Icon(Icons.photo_library_outlined),
          onPressed: () => _importPapers(fromPhotos: true),
        ),
      ],
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        children: [
          header('app', 'De la app'),
          if (!_closedPaperGroups.contains('app'))
            grid([
              for (final paper in AnnotationPaper.values)
                tile(
                  name: BrushCatalog.paperLabel(paper),
                  selected: doc.paperImage == null && doc.paper == paper,
                  image: ColoredBox(color: BrushCatalog.paperColor(paper)),
                  onTap: () => _controller.setPaper(paper),
                ),
            ]),
          if (favorites.isNotEmpty) ...[
            header('fav', 'Favoritos', icon: Icons.star_rounded),
            if (!_closedPaperGroups.contains('fav'))
              grid([for (final p in favorites) paperTile(p)]),
          ],
          for (final entry in groups.entries) ...[
            header('g:${entry.key}', '${entry.key} · ${entry.value.length}'),
            if (!_closedPaperGroups.contains('g:${entry.key}'))
              grid([for (final p in entry.value) paperTile(p)]),
          ],
          if (groups.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                'Importa tus papeles desde Archivos o Fotos, o déjalos en '
                'Archivos › En mi iPad › IRIS DP › Importar › Papeles '
                '(una subcarpeta por colección).',
                style: AppTypography.caption(palette),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _paperMenu(PaperTexture paper) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Renombrar'),
              onTap: () => Navigator.pop(context, 'rename'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('Quitar papel'),
              onTap: () => Navigator.pop(context, 'delete'),
            ),
          ],
        ),
      ),
    );
    if (!mounted) return;
    if (action == 'delete') return _deletePaper(paper);
    if (action != 'rename') return;
    final text = TextEditingController(text: paper.name);
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nombre del papel'),
        content: TextField(
          controller: text,
          autofocus: true,
          onSubmitted: (v) => Navigator.pop(context, v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, text.text),
            child: const Text('Aceptar'),
          ),
        ],
      ),
    );
    text.dispose();
    if (name == null) return;
    await PaperLibrary.instance.renamePaper(paper.id, name);
    if (mounted) setState(() {});
  }

  Widget _buildSettings() {
    final palette = context.palette;
    return SheetPanel(
      title: 'Ajustes',
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        children: [
          Text('Estabilizar el trazo', style: AppTypography.label(palette)),
          Slider(
            value: _streamline,
            onChanged: (v) => setState(() => _streamline = v),
          ),
          SwitchListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: const Text('Enderezar al mantener'),
            subtitle: const Text(
              'Mantén quieto el lápiz al acabar: recta, rectángulo o círculo.',
            ),
            value: _straighten,
            onChanged: (v) => setState(() => _straighten = v),
          ),
          SwitchListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: const Text('Dibujar con el dedo'),
            subtitle: const Text(
              'Si no, el dedo mueve el folio y el Pencil dibuja. Toque con '
              'dos dedos: deshacer; con tres: rehacer.',
            ),
            value: _fingerDraws,
            onChanged: (v) => setState(() => _fingerDraws = v),
          ),
        ],
      ),
    );
  }

  Widget _buildStyleChooser() {
    return Material(
      color: const Color(0xF21E1F21),
      borderRadius: BorderRadius.circular(16),
      elevation: 8,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final style in BrushCatalog.styles)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: _StyleCard(
                  style: style,
                  selected: style.id == _style.id,
                  onTap: () => _applyStyle(style),
                ),
              ),
            IconButton(
              tooltip: 'Cerrar estilos',
              color: Colors.white70,
              icon: const Icon(Icons.close, size: 18),
              onPressed: () => setState(() => _chooseStyle = false),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToolOptions(AppPalette palette) {
    final selected = _mode == _Mode.select ? _controller.selectedStamp : null;
    return Material(
      color: palette.surfaceElevated,
      elevation: 10,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 300,
        padding: const EdgeInsets.all(14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AnnotationTools.hint(_canvasTool),
              style: AppTypography.caption(palette),
            ),
            if (_mode == _Mode.stamp)
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 360),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final (group, kinds)
                          in AnnotationTools.stampGroups) ...[
                        const SizedBox(height: 10),
                        Text(group, style: AppTypography.label(palette)),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            for (final kind in kinds)
                              _StampChoice(
                                kind: kind,
                                color: _color,
                                selected: _stampKind == kind,
                                onTap: () => setState(() => _stampKind = kind),
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            if (_mode == _Mode.stamp || _mode == _Mode.text) ...[
              const SizedBox(height: 8),
              Text('Tamaño', style: AppTypography.caption(palette)),
              Slider(
                value: _stampSize,
                min: 0.03,
                max: 0.2,
                onChanged: (v) => setState(() => _stampSize = v),
              ),
            ],
            if (_mode == _Mode.select &&
                selected == null &&
                _controller.hasSelection) ...[
              const SizedBox(height: 8),
              Text(
                _controller.selectionCount == 1
                    ? '1 elemento seleccionado'
                    : '${_controller.selectionCount} elementos seleccionados',
                style: AppTypography.label(palette),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                children: [
                  OutlinedButton.icon(
                    onPressed: _controller.clearSelection,
                    icon: const Icon(Icons.deselect, size: 16),
                    label: const Text('Soltar'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _controller.deleteSelection,
                    icon: const Icon(Icons.delete_outline, size: 16),
                    label: const Text('Borrar'),
                  ),
                ],
              ),
            ],
            if (selected != null) ...[
              const SizedBox(height: 8),
              Text(
                AnnotationTools.stampLabel(selected.kind),
                style: AppTypography.label(palette),
              ),
              if (selected.kind != AnnotationStampKind.text)
                Slider(
                  value: selected.size.clamp(0.03, 0.2),
                  min: 0.03,
                  max: 0.2,
                  onChangeStart: (_) => _controller.beginGesture(),
                  onChanged: (v) => _controller.updateStamp(
                    selected.id,
                    size: v,
                    commit: false,
                  ),
                  onChangeEnd: (_) => _controller.endGesture(),
                ),
              if (selected.kind == AnnotationStampKind.camera ||
                  selected.kind == AnnotationStampKind.dolly ||
                  selected.kind == AnnotationStampKind.crane) ...[
                Text('Óptica', style: AppTypography.caption(palette)),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: [
                    for (final mm in const [
                      18.0,
                      25.0,
                      35.0,
                      50.0,
                      85.0,
                      135.0,
                    ])
                      ChoiceChip(
                        label: Text('${mm.round()}'),
                        selected: selected.lensMm == mm,
                        visualDensity: VisualDensity.compact,
                        onSelected: (_) => _setLens(selected, mm),
                      ),
                    FilterChip(
                      label: const Text('Full frame'),
                      selected: _fullFrame,
                      visualDensity: VisualDensity.compact,
                      onSelected: (v) {
                        setState(() => _fullFrame = v);
                        final lens = selected.lensMm;
                        if (lens != null) _setLens(selected, lens);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
              Wrap(
                spacing: 6,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => _nameStamp(selected),
                    icon: const Icon(Icons.edit_outlined, size: 16),
                    label: Text(
                      selected.kind == AnnotationStampKind.text
                          ? 'Editar'
                          : 'Nombre',
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: _deleteSelected,
                    icon: const Icon(Icons.delete_outline, size: 16),
                    label: const Text('Quitar'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Piezas ──────────────────────────────────────────────────────────────────

class _TopButton extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _TopButton({
    required this.tooltip,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return IconButton(
      tooltip: tooltip,
      onPressed: onTap,
      isSelected: selected,
      color: Colors.white70,
      selectedIcon: Icon(icon, color: palette.accent),
      icon: Icon(icon),
    );
  }
}

/// Deslizador vertical de la barra lateral (tamaño y opacidad).
class _VerticalSlider extends StatelessWidget {
  final String tooltip;
  final double value;
  final bool enabled;
  final String label;
  final ValueChanged<double> onChanged;
  final ValueChanged<double>? onChangeStart;
  final ValueChanged<double>? onChangeEnd;

  /// Pasos finos (+1 / −1) con los botones de arriba y abajo.
  final ValueChanged<int>? onStep;

  /// Tocar el número para escribirlo.
  final VoidCallback? onLabelTap;

  const _VerticalSlider({
    required this.tooltip,
    required this.value,
    required this.enabled,
    required this.label,
    required this.onChanged,
    this.onChangeStart,
    this.onChangeEnd,
    this.onStep,
    this.onLabelTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Column(
        children: [
          if (onStep != null)
            _StepButton(icon: Icons.add, onTap: () => onStep!(1)),
          SizedBox(
            height: 150,
            width: 40,
            child: RotatedBox(
              quarterTurns: 3,
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 6,
                  thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: 9,
                  ),
                  overlayShape: SliderComponentShape.noOverlay,
                ),
                child: Slider(
                  value: value.clamp(0.0, 1.0),
                  onChanged: enabled ? onChanged : null,
                  onChangeStart: onChangeStart,
                  onChangeEnd: onChangeEnd,
                ),
              ),
            ),
          ),
          if (onStep != null)
            _StepButton(icon: Icons.remove, onTap: () => onStep!(-1)),
          GestureDetector(
            onTap: onLabelTap,
            child: Text(
              enabled ? label : '',
              style: TextStyle(
                fontSize: 10,
                color: Colors.white54,
                decoration: onLabelTap == null
                    ? null
                    : TextDecoration.underline,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  final String text;

  const _Banner({required this.text});

  @override
  Widget build(BuildContext context) => Material(
    color: const Color(0xE6202124),
    borderRadius: BorderRadius.circular(20),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Text(text, style: const TextStyle(color: Colors.white)),
    ),
  );
}

class _StyleCard extends StatelessWidget {
  final SketchStyle style;
  final bool selected;
  final VoidCallback onTap;

  const _StyleCard({
    required this.style,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    // Muestra el pincel más característico del estilo.
    final brush = BrushCatalog.byId(
      style.shelf.firstWhere(
        (id) => id != 'graphite.hb',
        orElse: () => style.shelf.first,
      ),
    )!;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 170,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? palette.accent : Colors.white24,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                height: 46,
                width: double.infinity,
                child: CustomPaint(
                  painter: BrushPreviewPainter(
                    brush: brush,
                    color: Color(brush.defaultColor),
                    paper: style.paper,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              style.name,
              style: AppTypography.bodyMedium(
                palette,
              ).copyWith(color: Colors.white, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

class _StampChoice extends StatelessWidget {
  final AnnotationStampKind kind;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _StampChoice({
    required this.kind,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Tooltip(
      message: AnnotationTools.stampLabel(kind),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected ? palette.accent : palette.border,
              width: selected ? 2.5 : 1,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(7),
            child: CustomPaint(
              painter: _StampPreviewPainter(
                kind,
                color.computeLuminance() > 0.85
                    ? const Color(0xFF1A1A1A)
                    : color,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StampPreviewPainter extends CustomPainter {
  final AnnotationStampKind kind;
  final Color color;

  const _StampPreviewPainter(this.kind, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    // Se dibuja mirando a la derecha y algo desplazado a la izquierda para
    // que quepa el haz o el ángulo de visión.
    final offsetX = switch (kind) {
      AnnotationStampKind.camera ||
      AnnotationStampKind.light ||
      AnnotationStampKind.fresnel ||
      AnnotationStampKind.hmi => 0.3,
      AnnotationStampKind.softbox ||
      AnnotationStampKind.ledPanel ||
      AnnotationStampKind.sun => 0.38,
      AnnotationStampKind.crane => 0.42,
      _ => 0.5,
    };
    AnnotationBrushes.paintStamp(
      canvas,
      size,
      AnnotationStamp(
        id: 'preview',
        kind: kind,
        x: offsetX,
        y: 0.5,
        size: 0.34,
        colorArgb: color.toARGB32(),
      ),
    );
  }

  @override
  bool shouldRepaint(covariant _StampPreviewPainter oldDelegate) =>
      oldDelegate.kind != kind || oldDelegate.color != color;
}

/// Guías que no se exportan: tercios para encuadre o cuadrícula de planta.
class _GuidesPainter extends CustomPainter {
  final bool thirds;

  const _GuidesPainter({required this.thirds});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF2997FF).withValues(alpha: thirds ? 0.22 : 0.10)
      ..strokeWidth = 1;
    if (thirds) {
      for (var i = 1; i < 3; i++) {
        final x = size.width * i / 3;
        final y = size.height * i / 3;
        canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
        canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
      }
      return;
    }
    final step = size.shortestSide / 16;
    for (var x = step; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (var y = step; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _GuidesPainter oldDelegate) =>
      oldDelegate.thirds != thirds;
}

/// Botón pequeño de paso fino (+ / −) junto a un deslizador.
class _StepButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _StepButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    customBorder: const CircleBorder(),
    child: Padding(
      padding: const EdgeInsets.all(2),
      child: Icon(icon, size: 16, color: Colors.white70),
    ),
  );
}

/// El tamaño del pincel tal cual pintará: un círculo de su diámetro en
/// pantalla, con el número debajo.
class _SizePreview extends StatelessWidget {
  final double diameter;
  final String label;
  final Color color;

  const _SizePreview({
    required this.diameter,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final d = diameter.clamp(1.0, 2000.0);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: d,
          height: d,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withValues(alpha: 0.35),
            border: Border.all(color: Colors.white, width: 1),
            boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 6)],
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: Colors.black87,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            label,
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
        ),
      ],
    );
  }
}
