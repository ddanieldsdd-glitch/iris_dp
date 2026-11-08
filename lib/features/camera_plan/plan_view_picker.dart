import 'dart:math' as math;
import 'dart:typed_data';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/app_database.dart';
import '../../core/database/database_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../shared/history/edit_history.dart';
import '../../shared/history/shot_edits.dart';
import 'floor_plan_repository.dart';
import 'plan_data.dart';
import 'plan_renderer.dart';
import 'plan_thumbnail.dart';
import 'shot_plan_view.dart';

/// Elige la sección de la planta que representa a un plano.
Future<void> showPlanViewPicker(
  BuildContext context, {
  required PlanProjectData data,
  required Shot shot,
}) {
  final setup = data.setup(shot.lightSetupId);
  final shared = data.documentViewOf(setup);
  final (:focus, :crop) = data.framingOf(shot);
  return showDialog<void>(
    context: context,
    builder: (dialog) => Consumer(
      builder: (_, ref, _) => _PlanViewPicker(
        projectId: shot.projectId,
        title: 'Sección de la planta · Plano ${shot.number}',
        hint:
            'Arrastra para marcar la parte que importa. Lo que quede dentro '
            'representa al plano en el storyboard, el guion técnico y los '
            'PDF.',
        note: shared == null
            ? null
            : 'Sin sección propia, usa la de «${setup!.name}».',
        initial: crop,
        zone: focus,
        picture: (renderer) => renderer.shotPicture(shot),
        onSave: (rect) => saveShotFields(
          ref.read(databaseProvider),
          ref.read(editHistoryProvider),
          shot,
          ShotsCompanion(planViewJson: Value(encodeShotPlanView(rect))),
        ),
      ),
    ),
  );
}

/// Elige la sección de un esquema de luz o un boceto: la que sale en su
/// planta general y en los planos que no tengan la suya.
Future<void> showSetupViewPicker(
  BuildContext context, {
  required AppDatabase db,
  required PlanProjectData data,
  required LightSetup setup,
}) => showDialog<void>(
  context: context,
  builder: (_) => _PlanViewPicker(
    projectId: setup.projectId,
    title: 'Sección para documentos · ${setup.name}',
    hint:
        'Arrastra para marcar la parte que importa. Sale en los documentos '
        'en lugar de la planta entera, también en los planos de este esquema '
        'que no tengan una sección propia.',
    initial: data.documentViewOf(setup),
    zone: data.zoneOf(data.set(setup.locationBasePlanId)),
    picture: (renderer) => renderer.setupPicture(setup),
    onSave: (rect) => FloorPlanRepository(db).saveDocumentView(setup.id, rect),
  ),
);

class _PlanViewPicker extends ConsumerStatefulWidget {
  final int projectId;
  final String title;
  final String hint;
  final String? note;
  final Rect? initial;
  final Rect? zone;
  final Future<PlanPicture> Function(PlanRenderer renderer) picture;
  final Future<void> Function(Rect? rect) onSave;

  const _PlanViewPicker({
    required this.projectId,
    required this.title,
    required this.hint,
    required this.picture,
    required this.onSave,
    this.note,
    this.initial,
    this.zone,
  });

  @override
  ConsumerState<_PlanViewPicker> createState() => _PlanViewPickerState();
}

class _PlanViewPickerState extends ConsumerState<_PlanViewPicker> {
  PlanRenderer? _renderer;
  PlanPicture? _picture;
  bool _loaded = false;

  /// Lo que se ve de la planta, tal como sale en los documentos.
  Uint8List? _png;
  Rect? _view;
  Size? _renderedFor;

  /// Sección que se está eligiendo, en coordenadas de la planta. Nula: aún
  /// no se ha tocado. Arrastrarla repinta solo el recuadro.
  late final _selection = ValueNotifier<Rect?>(widget.initial ?? widget.zone);

  /// La sección si aún no se ha tocado: casi toda la planta.
  Rect? get _fallback => _view?.deflate(_view!.shortestSide * 0.1);

  Rect? get _current => _selection.value ?? _fallback;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _selection.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final renderer = await PlanRenderer.load(
      ref.read(databaseProvider),
      widget.projectId,
    );
    final picture = await widget.picture(renderer);
    if (!mounted) return;
    setState(() {
      _renderer = renderer;
      _picture = picture;
      _loaded = true;
    });
  }

  Future<void> _render(Size size, double pixelRatio) async {
    final view = _picture?.extent;
    if (view == null || _renderer == null) return;
    final png = await _renderer!.png(
      _picture!,
      size: size,
      pixelRatio: pixelRatio,
      view: view,
    );
    if (!mounted || size != _renderedFor) return;
    setState(() {
      _png = png;
      _view = view;
    });
  }

  Future<void> _save(Rect? rect) async {
    await widget.onSave(rect);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final screen = MediaQuery.sizeOf(context);
    final width = math.min(screen.width - 48, 960.0);
    // En un teléfono apaisado no cabe todo: el diálogo se desplaza.
    final height = (screen.height - 300).clamp(220.0, 620.0);

    return Dialog(
      backgroundColor: palette.surfaceElevated,
      child: SizedBox(
        width: width,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: SingleChildScrollView(
            child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(widget.title, style: AppTypography.titleMedium(palette)),
              const SizedBox(height: 4),
              Text(widget.hint, style: AppTypography.caption(palette)),
              if (widget.note != null) ...[
                const SizedBox(height: 2),
                Text(
                  widget.note!,
                  style: AppTypography.caption(
                    palette,
                  ).copyWith(color: palette.accent),
                ),
              ],
              const SizedBox(height: AppSpacing.md),
              SizedBox(
                height: height,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LayoutBuilder(builder: _canvas),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: AppSpacing.sm,
                children: [
                  Wrap(
                    children: [
                      TextButton(
                        onPressed: () => _save(null),
                        child: const Text('Quitar sección'),
                      ),
                      TextButton(
                        onPressed: _view == null
                            ? null
                            : () => _selection.value = _view,
                        child: const Text('Toda la planta'),
                      ),
                      if (widget.zone != null)
                        TextButton(
                          onPressed: () => _selection.value = widget.zone,
                          child: const Text('Zona del set'),
                        ),
                    ],
                  ),
                  Wrap(
                    spacing: AppSpacing.sm,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancelar'),
                      ),
                      FilledButton(
                        onPressed: _current == null
                            ? null
                            : () => _save(_current),
                        child: const Text('Usar esta sección'),
                      ),
                    ],
                  ),
                ],
              ),
            ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _canvas(BuildContext context, BoxConstraints box) {
    final palette = context.palette;
    final size = box.biggest;
    if (!_loaded) return const Center(child: CircularProgressIndicator());
    if (_picture?.extent == null) {
      return Center(
        child: Text(
          'Aún no hay planta que recortar.',
          style: AppTypography.bodyMedium(palette),
        ),
      );
    }
    if (_renderedFor != size) {
      _renderedFor = size;
      _render(size, MediaQuery.devicePixelRatioOf(context));
    }
    final whole = _view;
    final png = _png;
    if (whole == null || png == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final (:scale, :offset) = PlanThumbnail.frame(
      size,
      all: const [],
      focus: null,
      zones: const [],
      drawn: null,
      crop: whole,
    );
    return PlanSectionCanvas(
      selection: _selection,
      fallback: _fallback!,
      scale: scale,
      offset: offset,
      child: Image.memory(png, fit: BoxFit.fill, gaplessPlayback: true),
    );
  }
}

/// Reconoce el arrastre desde que se toca, sin esperar a ver si es un scroll:
/// el diálogo se desplaza y le quitaría el gesto en pantallas táctiles.
class _ImmediatePan extends PanGestureRecognizer {
  @override
  void addAllowedPointer(PointerDownEvent event) {
    super.addAllowedPointer(event);
    resolve(GestureDisposition.accepted);
  }
}

/// La planta con el recuadro de la sección encima.
///
/// El ratón manda varios movimientos por fotograma: cada uno se suma a la
/// sección de ese instante, no a la del último repintado.
class PlanSectionCanvas extends StatefulWidget {
  final ValueNotifier<Rect?> selection;

  /// La sección mientras [selection] sea nula.
  final Rect fallback;
  final double scale;
  final Offset offset;
  final Widget child;

  const PlanSectionCanvas({
    super.key,
    required this.selection,
    required this.fallback,
    required this.scale,
    required this.offset,
    required this.child,
  });

  @override
  State<PlanSectionCanvas> createState() => _PlanSectionCanvasState();
}

class _PlanSectionCanvasState extends State<PlanSectionCanvas> {
  static const _minSide = 80.0;

  Offset? _dragStart;

  Rect get _rect => widget.selection.value ?? widget.fallback;

  Offset _toPlan(Offset local) => (local - widget.offset) / widget.scale;

  void _resize(Alignment at, Offset delta) {
    final rect = _rect;
    var left = rect.left, top = rect.top;
    var right = rect.right, bottom = rect.bottom;
    if (at.x < 0) {
      left = math.min(left + delta.dx, right - _minSide);
    } else {
      right = math.max(right + delta.dx, left + _minSide);
    }
    if (at.y < 0) {
      top = math.min(top + delta.dy, bottom - _minSide);
    } else {
      bottom = math.max(bottom + delta.dy, top + _minSide);
    }
    widget.selection.value = Rect.fromLTRB(left, top, right, bottom);
  }

  Widget _pan({
    GestureDragStartCallback? onStart,
    required GestureDragUpdateCallback onUpdate,
    GestureDragEndCallback? onEnd,
    required Widget child,
  }) => RawGestureDetector(
    behavior: HitTestBehavior.opaque,
    gestures: {
      _ImmediatePan: GestureRecognizerFactoryWithHandlers<_ImmediatePan>(
        _ImmediatePan.new,
        (pan) => pan
          ..dragStartBehavior = DragStartBehavior.down
          ..onStart = onStart
          ..onUpdate = onUpdate
          ..onEnd = onEnd,
      ),
    },
    child: child,
  );

  Widget _corner(Rect shown, Alignment at, Color color) => Positioned(
    left: at.x < 0 ? shown.left - 14 : shown.right - 14,
    top: at.y < 0 ? shown.top - 14 : shown.bottom - 14,
    width: 28,
    height: 28,
    child: _pan(
      onUpdate: (d) => _resize(at, d.delta / widget.scale),
      child: Center(
        child: Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 1.5),
          ),
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Stack(
      children: [
        // Fuera del recuadro, arrastrar marca una sección nueva.
        Positioned.fill(
          child: _pan(
            onStart: (d) => _dragStart = _toPlan(d.localPosition),
            onUpdate: (d) {
              final start = _dragStart;
              if (start == null) return;
              final next = Rect.fromPoints(start, _toPlan(d.localPosition));
              if (next.width >= _minSide && next.height >= _minSide) {
                widget.selection.value = next;
              }
            },
            onEnd: (_) => _dragStart = null,
            child: RepaintBoundary(child: widget.child),
          ),
        ),
        Positioned.fill(
          child: ValueListenableBuilder<Rect?>(
            valueListenable: widget.selection,
            builder: (_, value, _) {
              final rect = value ?? widget.fallback;
              final shown = Rect.fromPoints(
                rect.topLeft * widget.scale + widget.offset,
                rect.bottomRight * widget.scale + widget.offset,
              );
              return Stack(
                children: [
                  Positioned.fill(
                    child: IgnorePointer(
                      child: CustomPaint(
                        painter: _DimOutside(
                          hole: shown,
                          stroke: palette.accent,
                        ),
                      ),
                    ),
                  ),
                  Positioned.fromRect(
                    rect: shown,
                    child: _pan(
                      onUpdate: (d) => widget.selection.value = _rect.shift(
                        d.delta / widget.scale,
                      ),
                      child: const MouseRegion(
                        cursor: SystemMouseCursors.move,
                        child: SizedBox.expand(),
                      ),
                    ),
                  ),
                  _corner(shown, Alignment.topLeft, palette.accent),
                  _corner(shown, Alignment.topRight, palette.accent),
                  _corner(shown, Alignment.bottomLeft, palette.accent),
                  _corner(shown, Alignment.bottomRight, palette.accent),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Oscurece lo que queda fuera de la sección.
class _DimOutside extends CustomPainter {
  final Rect hole;
  final Color stroke;

  const _DimOutside({required this.hole, required this.stroke});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      Path()
        ..fillType = PathFillType.evenOdd
        ..addRect(Offset.zero & size)
        ..addRect(hole),
      Paint()..color = Colors.black.withValues(alpha: 0.5),
    );
    canvas.drawRect(
      hole,
      Paint()
        ..color = stroke
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(_DimOutside old) =>
      old.hole != hole || old.stroke != stroke;
}
