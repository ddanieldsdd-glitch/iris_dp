import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import 'annotation_canvas.dart';
import 'annotation_document.dart';

/// Un dibujo hecho en el lienzo: la imagen y sus trazos, para poder seguir
/// dibujando otro día.
class SketchResult {
  final Uint8List png;
  final AnnotationDocument document;

  const SketchResult({required this.png, required this.document});
}

/// Archivo de trazos que acompaña a la imagen de un dibujo.
String sketchSidecarPath(String imagePath) => '$imagePath.trazos.json';

/// ¿Es [imagePath] un dibujo que se puede volver a abrir en el lienzo?
bool isEditableSketch(String imagePath) =>
    File(sketchSidecarPath(imagePath)).existsSync();

/// Los trazos de un dibujo guardado; vacío si no los tiene.
AnnotationDocument readSketchDocument(String imagePath) {
  final file = File(sketchSidecarPath(imagePath));
  if (!file.existsSync()) return const AnnotationDocument();
  try {
    return AnnotationDocument.decode(file.readAsStringSync());
  } catch (_) {
    return const AnnotationDocument();
  }
}

/// Guarda los trazos junto a la imagen ya almacenada en [imagePath].
Future<void> writeSketchDocument(
  String imagePath,
  AnnotationDocument document,
) => File(sketchSidecarPath(imagePath)).writeAsString(document.encode());

/// Papel cuadriculado de los bocetos técnicos (plantas a mano): una
/// cuadrícula suave, con línea más marcada cada cinco.
class SketchGridPainter extends CustomPainter {
  const SketchGridPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final step = size.width / 40;
    final thin = Paint()
      ..color = const Color(0xFFD6E4F0)
      ..strokeWidth = 1;
    final thick = Paint()
      ..color = const Color(0xFFB4CCE2)
      ..strokeWidth = 1.4;
    var i = 0;
    for (var x = 0.0; x <= size.width; x += step, i++) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        i % 5 == 0 ? thick : thin,
      );
    }
    i = 0;
    for (var y = 0.0; y <= size.height; y += step, i++) {
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        i % 5 == 0 ? thick : thin,
      );
    }
  }

  @override
  bool shouldRepaint(SketchGridPainter oldDelegate) => false;
}

/// Pinta [document] sobre papel blanco (o cuadriculado, con [gridPaper]) y
/// lo devuelve en PNG.
Future<Uint8List> renderSketchPng(
  AnnotationDocument document, {
  Size size = const Size(1600, 900),
  bool gridPaper = false,
  String? underlayPath,
}) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder, Offset.zero & size);
  canvas.drawRect(Offset.zero & size, Paint()..color = Colors.white);
  final underlay = await _decodeFile(underlayPath);
  if (underlay != null) {
    paintImage(
      canvas: canvas,
      rect: Offset.zero & size,
      image: underlay,
      fit: BoxFit.contain,
      opacity: kSketchUnderlayOpacity,
    );
    underlay.dispose();
  }
  if (gridPaper) const SketchGridPainter().paint(canvas, size);
  AnnotationPainter(document: document).paint(canvas, size);
  final image = await recorder.endRecording().toImage(
    size.width.round(),
    size.height.round(),
  );
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return data!.buffer.asUint8List();
}

/// Un color del lápiz y lo que significa en ese lienzo.
class SketchColor {
  final Color color;
  final String meaning;

  const SketchColor(this.color, this.meaning);
}

/// Colores de un boceto de planta: el mismo lienzo que el storyboard, pero
/// cada color dice qué es, como en una planta de luz.
const kPlanSketchColors = [
  SketchColor(Color(0xFF111111), 'Paredes y entorno'),
  SketchColor(Color(0xFFFF9500), 'Luz cálida (tungsteno, CTO)'),
  SketchColor(Color(0xFF007AFF), 'Luz fría (HMI, día, luna)'),
  SketchColor(Color(0xFFFF3B30), 'Cámara y encuadre'),
  SketchColor(Color(0xFF34C759), 'Personajes y recorridos'),
  SketchColor(Color(0xFF8E8E93), 'Grip: banderas, telas, rebotes'),
  SketchColor(Color(0xFFAF52DE), 'Notas'),
];

/// Transparencia de la imagen que se calca debajo del papel.
const kSketchUnderlayOpacity = 0.5;

Future<ui.Image?> _decodeFile(String? path) async {
  if (path == null) return null;
  final file = File(path);
  if (!file.existsSync()) return null;
  try {
    final codec = await ui.instantiateImageCodec(await file.readAsBytes());
    return (await codec.getNextFrame()).image;
  } catch (_) {
    return null;
  }
}

/// Abre el lienzo de dibujo. Devuelve el dibujo al guardar; nulo si se
/// cierra sin guardar.
Future<SketchResult?> showSketchPad(
  BuildContext context, {
  required String title,
  AnnotationDocument initial = const AnnotationDocument(),
  double aspectRatio = 16 / 9,
  bool gridPaper = false,
  String? underlayPath,
  Future<String?> Function(BuildContext context)? onPickUnderlay,
  List<SketchColor>? colors,
}) {
  return Navigator.of(context, rootNavigator: true).push<SketchResult>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => SketchPad(
        title: title,
        initial: initial,
        aspectRatio: aspectRatio,
        gridPaper: gridPaper,
        underlayPath: underlayPath,
        onPickUnderlay: onPickUnderlay,
        colors: colors,
      ),
    ),
  );
}

/// Lienzo blanco para dibujar a mano, con ratón o Apple Pencil: lápiz,
/// rotulador, flecha y goma, colores, grosor, deshacer y rehacer.
class SketchPad extends StatefulWidget {
  final String title;
  final AnnotationDocument initial;
  final double aspectRatio;

  /// Papel cuadriculado, para los bocetos de planta.
  final bool gridPaper;

  /// Imagen que se calca debajo del papel (una cenital, un storyboard).
  final String? underlayPath;

  /// Con él, un botón para poner o cambiar la imagen de debajo; devuelve la
  /// ruta nueva (o nula para quitarla).
  final Future<String?> Function(BuildContext context)? onPickUnderlay;

  /// Colores con significado (boceto de planta); sin ellos, los de siempre.
  final List<SketchColor>? colors;

  const SketchPad({
    super.key,
    required this.title,
    this.initial = const AnnotationDocument(),
    this.aspectRatio = 16 / 9,
    this.gridPaper = false,
    this.underlayPath,
    this.onPickUnderlay,
    this.colors,
  });

  @override
  State<SketchPad> createState() => _SketchPadState();
}

class _SketchPadState extends State<SketchPad> {
  late final _controller = AnnotationCanvasController(document: widget.initial);
  AnnotationToolType _tool = AnnotationToolType.pen;
  late Color _color = widget.colors?.first.color ?? SketchToolbar.colors.first;
  double _width = 6;
  bool _saving = false;
  late String? _underlay = widget.underlayPath;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    final document = _controller.document;
    final png = await renderSketchPng(
      document,
      size: Size(1600, 1600 / widget.aspectRatio),
      gridPaper: widget.gridPaper,
      underlayPath: _underlay,
    );
    if (!mounted) return;
    Navigator.of(context).pop(SketchResult(png: png, document: document));
  }

  Future<void> _close() async {
    final changed = _controller.canUndo;
    if (changed) {
      final leave = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('¿Salir sin guardar el dibujo?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Seguir dibujando'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Salir sin guardar'),
            ),
          ],
        ),
      );
      if (leave != true || !mounted) return;
    }
    Navigator.of(context).pop();
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
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          backgroundColor: palette.background,
          body: SafeArea(
            child: Column(
              children: [
                Container(
                  color: palette.surfaceElevated,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: AppSpacing.sm,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          widget.title,
                          style: AppTypography.titleMedium(palette),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (widget.onPickUnderlay case final pick?)
                        TextButton.icon(
                          onPressed: _saving
                              ? null
                              : () async {
                                  final path = await pick(context);
                                  if (mounted) setState(() => _underlay = path);
                                },
                          icon: const Icon(Icons.image_outlined, size: 18),
                          label: Text(
                            _underlay == null
                                ? 'Imagen debajo'
                                : 'Cambiar imagen',
                          ),
                        ),
                      TextButton(
                        onPressed: _saving ? null : _close,
                        child: const Text('Cancelar'),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      FilledButton.icon(
                        onPressed: _saving ? null : _save,
                        icon: const Icon(Icons.check, size: 18),
                        label: const Text('Guardar dibujo'),
                      ),
                    ],
                  ),
                ),
                SketchToolbar(
                  meanings: widget.colors,
                  controller: _controller,
                  tool: _tool,
                  color: _color,
                  width: _width,
                  onToolChanged: (tool) => setState(() => _tool = tool),
                  onColorChanged: (color) => setState(() {
                    _color = color;
                    if (_tool == AnnotationToolType.eraser) {
                      _tool = AnnotationToolType.pen;
                    }
                  }),
                  onWidthChanged: (width) => setState(() => _width = width),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Center(
                      child: AspectRatio(
                        aspectRatio: widget.aspectRatio,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border.all(color: palette.border),
                          ),
                          child: ClipRect(
                            child: AnnotationCanvas(
                              controller: _controller,
                              enabled: true,
                              tool: _tool,
                              color: _color,
                              width: _width,
                              acceptTouch: true,
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  if (_underlay != null &&
                                      File(_underlay!).existsSync())
                                    Opacity(
                                      opacity: kSketchUnderlayOpacity,
                                      child: Image.file(
                                        File(_underlay!),
                                        fit: BoxFit.contain,
                                      ),
                                    ),
                                  if (widget.gridPaper)
                                    const CustomPaint(
                                      painter: SketchGridPainter(),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Herramientas de dibujo a mano: las mismas en el lienzo blanco y donde
/// se quiera dibujar.
class SketchToolbar extends StatelessWidget {
  /// Colores del lápiz; el primero es el de partida.
  static const colors = [
    Color(0xFF111111),
    Color(0xFFFF3B30),
    Color(0xFF007AFF),
    Color(0xFF34C759),
    Color(0xFFFFCC00),
    Color(0xFFFF9500),
    Color(0xFFAF52DE),
    Color(0xFF8E8E93),
  ];

  final AnnotationCanvasController controller;
  final AnnotationToolType tool;
  final Color color;
  final double width;
  final ValueChanged<AnnotationToolType> onToolChanged;
  final ValueChanged<Color> onColorChanged;
  final ValueChanged<double> onWidthChanged;

  /// Colores con significado; sin ellos, [colors] sin nombre.
  final List<SketchColor>? meanings;

  const SketchToolbar({
    super.key,
    this.meanings,
    required this.controller,
    required this.tool,
    required this.color,
    required this.width,
    required this.onToolChanged,
    required this.onColorChanged,
    required this.onWidthChanged,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    Widget toolButton(IconData icon, String tooltip, AnnotationToolType value) {
      return IconButton(
        tooltip: tooltip,
        onPressed: () => onToolChanged(value),
        color: tool == value ? palette.accent : palette.textSecondary,
        icon: Icon(icon),
      );
    }

    return Material(
      color: palette.surface,
      child: SizedBox(
        height: 56,
        child: ListenableBuilder(
          listenable: controller,
          builder: (context, _) => ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: [
              toolButton(Icons.edit_outlined, 'Lápiz', AnnotationToolType.pen),
              toolButton(
                Icons.border_color_outlined,
                'Rotulador',
                AnnotationToolType.highlighter,
              ),
              toolButton(Icons.north_east, 'Flecha', AnnotationToolType.arrow),
              toolButton(
                Icons.auto_fix_normal_outlined,
                'Goma',
                AnnotationToolType.eraser,
              ),
              const VerticalDivider(indent: 12, endIndent: 12),
              for (final (choice, meaning) in [
                if (meanings case final named?)
                  for (final m in named) (m.color, m.meaning)
                else
                  for (final c in colors) (c, 'Color del lápiz'),
              ])
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: Tooltip(
                    message: meaning,
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () => onColorChanged(choice),
                      child: Container(
                        width: 26,
                        height: 26,
                        margin: const EdgeInsets.symmetric(vertical: 15),
                        decoration: BoxDecoration(
                          color: choice,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: choice == color
                                ? palette.accent
                                : palette.border,
                            width: choice == color ? 3 : 1,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              if (meanings case final named?)
                for (final m in named)
                  if (m.color == color)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.only(left: 6),
                        child: Text(
                          m.meaning,
                          style: AppTypography.caption(
                            palette,
                          ).copyWith(color: palette.textSecondary),
                        ),
                      ),
                    ),
              const SizedBox(width: 8),
              Tooltip(
                message: 'Grosor',
                child: SizedBox(
                  width: 140,
                  child: Slider(
                    value: width,
                    min: 2,
                    max: 24,
                    onChanged: onWidthChanged,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Deshacer (⌘Z)',
                onPressed: controller.canUndo ? controller.undo : null,
                icon: const Icon(Icons.undo),
              ),
              IconButton(
                tooltip: 'Rehacer (⇧⌘Z)',
                onPressed: controller.canRedo ? controller.redo : null,
                icon: const Icon(Icons.redo),
              ),
              IconButton(
                tooltip: 'Borrar todo',
                onPressed: controller.document.isEmpty
                    ? null
                    : controller.clear,
                icon: const Icon(Icons.delete_sweep_outlined),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
