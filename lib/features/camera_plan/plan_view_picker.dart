import 'dart:math' as math;

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/app_database.dart';
import '../../core/database/database_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../shared/history/edit_history.dart';
import '../../shared/history/shot_edits.dart';
import 'plan_data.dart';
import 'plan_thumbnail.dart';
import 'shot_plan_view.dart';

/// Elige la sección de la planta que representa a un plano.
Future<void> showPlanViewPicker(
  BuildContext context, {
  required PlanProjectData data,
  required Shot shot,
}) => showDialog<void>(
  context: context,
  builder: (_) => _PlanViewPicker(data: data, shot: shot),
);

class _PlanViewPicker extends ConsumerStatefulWidget {
  final PlanProjectData data;
  final Shot shot;

  const _PlanViewPicker({required this.data, required this.shot});

  @override
  ConsumerState<_PlanViewPicker> createState() => _PlanViewPickerState();
}

class _PlanViewPickerState extends ConsumerState<_PlanViewPicker> {
  static const _minSide = 80.0;

  late final _own = [
    ...widget.data.lightOfShot(widget.shot),
    ...widget.data.ownOfShot(widget.shot),
  ];
  late final _base = widget.data.baseOfShot(widget.shot);
  late final _drawings = widget.data.drawingsOfShot(widget.shot);
  late final _zone = widget.data.framingOf(widget.shot).focus;

  /// Sección que se está eligiendo, en coordenadas de la planta. Nula: la
  /// planta entera, hasta saber lo que mide al pintarse.
  late Rect? _rect = widget.data.framingOf(widget.shot).crop ?? _zone;

  /// La planta entera tal como se ve en el lienzo.
  Rect? _whole;

  Rect _wholePlan(double scale, Offset offset, Size size) => Rect.fromPoints(
    (Offset.zero - offset) / scale,
    (size.bottomRight(Offset.zero) - offset) / scale,
  );

  Future<void> _save(Rect? rect) async {
    await saveShotFields(
      ref.read(databaseProvider),
      ref.read(editHistoryProvider),
      widget.shot,
      ShotsCompanion(planViewJson: Value(encodeShotPlanView(rect))),
    );
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final screen = MediaQuery.sizeOf(context);
    final width = math.min(screen.width - 48, 960.0);
    final height = math.min(screen.height - 220, 620.0);

    return Dialog(
      backgroundColor: palette.surfaceElevated,
      child: SizedBox(
        width: width,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Sección de la planta · Plano ${widget.shot.number}',
                style: AppTypography.titleMedium(palette),
              ),
              const SizedBox(height: 4),
              Text(
                'Arrastra el recuadro y sus esquinas. Lo que quede dentro '
                'representa al plano en el storyboard, el guion técnico y los '
                'PDF.',
                style: AppTypography.caption(palette),
              ),
              const SizedBox(height: AppSpacing.md),
              SizedBox(
                height: height,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LayoutBuilder(builder: _canvas),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  TextButton(
                    onPressed: () => _save(null),
                    child: const Text('Quitar sección'),
                  ),
                  TextButton(
                    onPressed: () => setState(() => _rect = _whole),
                    child: const Text('Toda la planta'),
                  ),
                  if (_zone != null)
                    TextButton(
                      onPressed: () => setState(() => _rect = _zone),
                      child: const Text('Zona del set'),
                    ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancelar'),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  FilledButton(
                    onPressed: _rect == null ? null : () => _save(_rect),
                    child: const Text('Usar esta sección'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _canvas(BuildContext context, BoxConstraints box) {
    final palette = context.palette;
    final size = box.biggest;
    final all = [..._base, ..._own];
    final drawn = PlanThumbnail.drawingBounds(_drawings);
    if (all.isEmpty && drawn == null) {
      return Center(
        child: Text(
          'Este plano aún no tiene planta.',
          style: AppTypography.bodyMedium(palette),
        ),
      );
    }
    final (:scale, :offset) = PlanThumbnail.frame(
      size,
      all: all,
      focus: null,
      zones: const [],
      drawn: drawn,
    );
    final whole = _whole = _wholePlan(scale, offset, size);
    final rect = _rect ?? whole.deflate(whole.shortestSide * 0.1);
    final shown = Rect.fromPoints(
      rect.topLeft * scale + offset,
      rect.bottomRight * scale + offset,
    );

    void update(Rect next) => setState(() => _rect = next);

    Widget corner(Alignment at) {
      return Positioned(
        left: at.x < 0 ? shown.left - 12 : shown.right - 12,
        top: at.y < 0 ? shown.top - 12 : shown.bottom - 12,
        width: 24,
        height: 24,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanUpdate: (d) {
            final delta = d.delta / scale;
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
            update(Rect.fromLTRB(left, top, right, bottom));
          },
          child: Center(
            child: Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: palette.accent,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1.5),
              ),
            ),
          ),
        ),
      );
    }

    return Stack(
      children: [
        Positioned.fill(
          child: PlanThumbnail(
            elements: _own,
            inherited: _base,
            drawings: _drawings,
          ),
        ),
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(
              painter: _DimOutside(hole: shown, stroke: palette.accent),
            ),
          ),
        ),
        Positioned.fromRect(
          rect: shown,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanUpdate: (d) => update(rect.shift(d.delta / scale)),
            child: const MouseRegion(
              cursor: SystemMouseCursors.move,
              child: SizedBox.expand(),
            ),
          ),
        ),
        corner(Alignment.topLeft),
        corner(Alignment.topRight),
        corner(Alignment.bottomLeft),
        corner(Alignment.bottomRight),
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
      Path.combine(
        PathOperation.difference,
        Path()..addRect(Offset.zero & size),
        Path()..addRect(hole),
      ),
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
