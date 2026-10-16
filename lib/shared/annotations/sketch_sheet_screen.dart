import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import 'annotation_brushes.dart';
import 'annotation_canvas.dart';
import 'annotation_document.dart';
import 'annotation_raster.dart';
import 'annotation_tools.dart';

/// Para qué es el folio: cambia herramientas, colores y guías por defecto.
enum SketchSheetPurpose {
  /// Boceto de planta de luz y cámara (vista cenital, sellos).
  lightingPlan,

  /// Viñeta de storyboard (valores de gris, aguadas, color).
  storyboard,
}

class SketchSheetResult {
  final AnnotationDocument document;

  /// PNG del dibujo sobre blanco (solo si se pidió con `exportPng`).
  final Uint8List? png;

  const SketchSheetResult({required this.document, this.png});
}

/// Folio a pantalla completa para dibujar a mano: planta de luz y cámara o
/// viñeta de storyboard.
class SketchSheetScreen extends StatefulWidget {
  final String title;
  final AnnotationDocument initialDocument;
  final SketchSheetPurpose purpose;

  /// Ancho / alto del folio.
  final double aspectRatio;
  final bool exportPng;

  const SketchSheetScreen({
    super.key,
    required this.title,
    required this.initialDocument,
    required this.purpose,
    required this.aspectRatio,
    this.exportPng = false,
  });

  static Future<SketchSheetResult?> open(
    BuildContext context, {
    required String title,
    required AnnotationDocument document,
    required SketchSheetPurpose purpose,
    double? aspectRatio,
    bool exportPng = false,
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
        ),
      ),
    );
  }

  @override
  State<SketchSheetScreen> createState() => _SketchSheetScreenState();
}

class _SketchSheetScreenState extends State<SketchSheetScreen> {
  late final AnnotationCanvasController _controller;
  late AnnotationToolType _tool;
  late Color _color;
  AnnotationStampKind _stampKind = AnnotationStampKind.camera;
  double _stampSize = 0.07;
  bool _guides = true;
  bool _saving = false;

  final Map<AnnotationToolType, double> _widths = {
    AnnotationToolType.pen: 4,
    AnnotationToolType.pencil: 4,
    AnnotationToolType.ink: 5,
    AnnotationToolType.marker: 9,
    AnnotationToolType.charcoal: 14,
    AnnotationToolType.wash: 40,
    AnnotationToolType.airbrush: 60,
    AnnotationToolType.hatch: 6,
    AnnotationToolType.line: 4,
    AnnotationToolType.arrow: 5,
    AnnotationToolType.eraseArea: 30,
    AnnotationToolType.highlighter: 14,
  };

  final Map<AnnotationToolType, double> _opacities = {
    AnnotationToolType.fill: 0.55,
    AnnotationToolType.hatch: 0.8,
  };

  bool get _storyboard => widget.purpose == SketchSheetPurpose.storyboard;

  List<List<AnnotationToolType>> get _toolGroups => _storyboard
      ? const [
          [
            AnnotationToolType.pencil,
            AnnotationToolType.ink,
            AnnotationToolType.marker,
            AnnotationToolType.charcoal,
          ],
          [
            AnnotationToolType.wash,
            AnnotationToolType.airbrush,
            AnnotationToolType.fill,
            AnnotationToolType.hatch,
          ],
          [
            AnnotationToolType.line,
            AnnotationToolType.arrow,
            AnnotationToolType.text,
          ],
          [
            AnnotationToolType.select,
            AnnotationToolType.eraseArea,
            AnnotationToolType.eraser,
          ],
        ]
      : const [
          [
            AnnotationToolType.pencil,
            AnnotationToolType.ink,
            AnnotationToolType.marker,
          ],
          [
            AnnotationToolType.stamp,
            AnnotationToolType.line,
            AnnotationToolType.arrow,
            AnnotationToolType.text,
          ],
          [
            AnnotationToolType.fill,
            AnnotationToolType.hatch,
            AnnotationToolType.wash,
            AnnotationToolType.airbrush,
          ],
          [
            AnnotationToolType.select,
            AnnotationToolType.eraseArea,
            AnnotationToolType.eraser,
          ],
        ];

  List<Color> get _swatches => _storyboard
      ? const [
          Color(0xFF111111),
          Color(0xFF3A3A3A),
          Color(0xFF6B6B6B),
          Color(0xFF9E9E9E),
          Color(0xFFCFCFCF),
          Color(0xFFFFFFFF),
          Color(0xFF7FB2D9),
          Color(0xFF3E6E9C),
          Color(0xFF5B6C8F),
          Color(0xFFD9B98C),
          Color(0xFFE8B996),
          Color(0xFF6B8E4E),
          Color(0xFFFFC857),
          Color(0xFFE07A2F),
          Color(0xFFC0392B),
        ]
      : const [
          Color(0xFF1A1A1A),
          Color(0xFF1F3FBF),
          Color(0xFFD32F2F),
          Color(0xFF8A8A8A),
          Color(0xFF2E7D32),
          Color(0xFFFFB300),
          Color(0xFF4FC3F7),
          Color(0xFFFFFFFF),
        ];

  @override
  void initState() {
    super.initState();
    _controller = AnnotationCanvasController(document: widget.initialDocument);
    _tool = _storyboard ? AnnotationToolType.pencil : AnnotationToolType.pencil;
    _color = _swatches.first;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _dirty => _controller.document != widget.initialDocument;

  double get _width => _widths[_tool] ?? 6;
  double get _opacity => _opacities[_tool] ?? 1;

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

  Future<void> _pickCustomColor() async {
    final hsv = HSVColor.fromColor(_color);
    var hue = hsv.hue;
    var saturation = hsv.saturation;
    var value = hsv.value;
    final picked = await showDialog<Color>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) {
          final color = HSVColor.fromAHSV(1, hue, saturation, value).toColor();
          Widget slider(
            String label,
            double v,
            double max,
            ValueChanged<double> f,
          ) => Row(
            children: [
              SizedBox(width: 74, child: Text(label)),
              Expanded(
                child: Slider(value: v, max: max, onChanged: f),
              ),
            ],
          );
          return AlertDialog(
            title: const Text('Color'),
            content: SizedBox(
              width: 320,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    height: 44,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.black12),
                    ),
                  ),
                  const SizedBox(height: 12),
                  slider('Tono', hue, 360, (v) => setLocal(() => hue = v)),
                  slider(
                    'Saturación',
                    saturation,
                    1,
                    (v) => setLocal(() => saturation = v),
                  ),
                  slider('Brillo', value, 1, (v) => setLocal(() => value = v)),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, color),
                child: const Text('Usar'),
              ),
            ],
          );
        },
      ),
    );
    if (picked != null) _setColor(picked);
  }

  void _setColor(Color color) {
    setState(() => _color = color);
    final selected = _controller.selectedStamp;
    if (_tool == AnnotationToolType.select && selected != null) {
      _controller.updateStamp(selected.id, colorArgb: color.toARGB32());
    }
  }

  void _deleteSelected() {
    final selected = _controller.selectedStamp;
    if (selected != null) _controller.removeStamp(selected.id);
  }

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
              backgroundColor: palette.background,
              appBar: _buildAppBar(palette),
              body: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildToolRail(palette),
                  Expanded(child: _buildSheet(palette)),
                  _buildSidePanel(palette),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(AppPalette palette) {
    return AppBar(
      backgroundColor: palette.surface,
      leading: IconButton(
        tooltip: 'Cerrar',
        icon: const Icon(Icons.close),
        onPressed: _close,
      ),
      title: Text(widget.title, style: AppTypography.titleMedium(palette)),
      actions: [
        IconButton(
          tooltip: 'Deshacer (⌘Z)',
          onPressed: _controller.canUndo ? _controller.undo : null,
          icon: const Icon(Icons.undo),
        ),
        IconButton(
          tooltip: 'Rehacer (⇧⌘Z)',
          onPressed: _controller.canRedo ? _controller.redo : null,
          icon: const Icon(Icons.redo),
        ),
        IconButton(
          tooltip: _storyboard ? 'Guías de tercios' : 'Cuadrícula',
          isSelected: _guides,
          onPressed: () => setState(() => _guides = !_guides),
          icon: Icon(_storyboard ? Icons.grid_3x3 : Icons.grid_4x4),
        ),
        IconButton(
          tooltip: 'Vaciar folio',
          onPressed: _controller.document.isEmpty ? null : _controller.clear,
          icon: const Icon(Icons.delete_sweep_outlined),
        ),
        const SizedBox(width: 8),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
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
        const SizedBox(width: 12),
      ],
    );
  }

  Widget _buildToolRail(AppPalette palette) {
    return Container(
      width: 64,
      color: palette.surface,
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          for (var g = 0; g < _toolGroups.length; g++) ...[
            if (g > 0)
              Divider(
                indent: 14,
                endIndent: 14,
                height: 14,
                color: palette.divider,
              ),
            for (final tool in _toolGroups[g])
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Tooltip(
                  message: AnnotationTools.label(tool),
                  waitDuration: const Duration(milliseconds: 400),
                  child: _RailButton(
                    icon: AnnotationTools.icon(tool),
                    label: AnnotationTools.label(tool),
                    selected: _tool == tool,
                    palette: palette,
                    onTap: () => setState(() => _tool = tool),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildSheet(AppPalette palette) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: AspectRatio(
          aspectRatio: widget.aspectRatio,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white,
              border: _storyboard
                  ? Border.all(color: const Color(0xFF111111), width: 2)
                  : null,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: ClipRect(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  AnnotationCanvas(
                    controller: _controller,
                    enabled: !_saving,
                    tool: _tool,
                    color: _color,
                    width: _width,
                    opacity: _opacity,
                    stampKind: _stampKind,
                    stampSize: _stampSize,
                    acceptTouch: true,
                    onTextRequested: () => _askText(),
                    onStampEditRequested: _nameStamp,
                  ),
                  if (_guides)
                    IgnorePointer(
                      child: CustomPaint(
                        painter: _GuidesPainter(thirds: _storyboard),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSidePanel(AppPalette palette) {
    final selected = _tool == AnnotationToolType.select
        ? _controller.selectedStamp
        : null;
    final sizeEditable = _widths.containsKey(_tool);
    final opacityEditable =
        AnnotationBrushes.isStrokeTool(_tool) &&
        _tool != AnnotationToolType.eraseArea;

    return Container(
      width: 232,
      color: palette.surface,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          Text(
            AnnotationTools.label(_tool).toUpperCase(),
            style: AppTypography.label(palette),
          ),
          const SizedBox(height: 6),
          Text(
            AnnotationTools.hint(_tool),
            style: AppTypography.caption(palette),
          ),
          const SizedBox(height: 18),
          if (_tool == AnnotationToolType.stamp) ...[
            _sectionTitle('Sello', palette),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final kind in AnnotationStampKind.values.where(
                  (k) => k != AnnotationStampKind.text,
                ))
                  _StampChoice(
                    kind: kind,
                    color: _color,
                    selected: _stampKind == kind,
                    palette: palette,
                    onTap: () => setState(() => _stampKind = kind),
                  ),
              ],
            ),
            const SizedBox(height: 14),
          ],
          _sectionTitle('Color', palette),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final swatch in _swatches)
                _Swatch(
                  color: swatch,
                  selected: swatch.toARGB32() == _color.toARGB32(),
                  palette: palette,
                  onTap: () => _setColor(swatch),
                ),
              InkWell(
                customBorder: const CircleBorder(),
                onTap: _pickCustomColor,
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: palette.borderBright),
                    gradient: const SweepGradient(
                      colors: [
                        Colors.red,
                        Colors.yellow,
                        Colors.green,
                        Colors.cyan,
                        Colors.blue,
                        Colors.purple,
                        Colors.red,
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (sizeEditable) ...[
            _sectionTitle(
              _tool == AnnotationToolType.hatch ? 'Separación' : 'Grosor',
              palette,
            ),
            Slider(
              value: _width.clamp(1, 120),
              min: 1,
              max: 120,
              onChanged: (v) => setState(() => _widths[_tool] = v),
            ),
          ],
          if (_tool == AnnotationToolType.stamp ||
              _tool == AnnotationToolType.text) ...[
            _sectionTitle('Tamaño', palette),
            Slider(
              value: _stampSize,
              min: 0.03,
              max: 0.2,
              onChanged: (v) => setState(() => _stampSize = v),
            ),
          ],
          if (opacityEditable) ...[
            _sectionTitle('Opacidad', palette),
            Slider(
              value: _opacity,
              min: 0.05,
              max: 1,
              onChanged: (v) => setState(() => _opacities[_tool] = v),
            ),
          ],
          if (selected != null) ...[
            const SizedBox(height: 10),
            Divider(color: palette.divider),
            const SizedBox(height: 8),
            _sectionTitle(AnnotationTools.stampLabel(selected.kind), palette),
            if (selected.kind != AnnotationStampKind.text) ...[
              Text('Tamaño', style: AppTypography.caption(palette)),
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
            ],
            Wrap(
              spacing: 6,
              runSpacing: 6,
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
    );
  }

  Widget _sectionTitle(String text, AppPalette palette) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(text, style: AppTypography.label(palette)),
  );
}

class _RailButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final AppPalette palette;
  final VoidCallback onTap;

  const _RailButton({
    required this.icon,
    required this.label,
    required this.selected,
    required this.palette,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8),
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: selected ? palette.accent.withValues(alpha: 0.18) : null,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 20,
              color: selected ? palette.accent : palette.textSecondary,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.fade,
              softWrap: false,
              style: TextStyle(
                fontSize: 9,
                color: selected ? palette.accent : palette.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  final Color color;
  final bool selected;
  final AppPalette palette;
  final VoidCallback onTap;

  const _Swatch({
    required this.color,
    required this.selected,
    required this.palette,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      customBorder: const CircleBorder(),
      onTap: onTap,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? palette.accent : palette.border,
            width: selected ? 2.5 : 1,
          ),
        ),
      ),
    );
  }
}

class _StampChoice extends StatelessWidget {
  final AnnotationStampKind kind;
  final Color color;
  final bool selected;
  final AppPalette palette;
  final VoidCallback onTap;

  const _StampChoice({
    required this.kind,
    required this.color,
    required this.selected,
    required this.palette,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: AnnotationTools.stampLabel(kind),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 60,
          height: 60,
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
      AnnotationStampKind.camera || AnnotationStampKind.light => 0.3,
      AnnotationStampKind.softbox || AnnotationStampKind.sun => 0.38,
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
