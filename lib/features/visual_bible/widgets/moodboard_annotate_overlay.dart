import 'dart:io';
import 'dart:math' as math;

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../moodboard_annotation_store.dart';
import '../visual_bible_model.dart';

enum _AnnotateTool { draw, arrow, text, none }

/// Overlay Stitch: anotar still + hilos de comentarios (BibleComments).
class MoodboardAnnotateOverlay extends ConsumerStatefulWidget {
  final int bibleId;
  final MoodboardImageModel image;
  final String? sceneLabel;
  final VoidCallback onClose;

  const MoodboardAnnotateOverlay({
    super.key,
    required this.bibleId,
    required this.image,
    this.sceneLabel,
    required this.onClose,
  });

  static Future<void> show({
    required BuildContext context,
    required int bibleId,
    required MoodboardImageModel image,
    String? sceneLabel,
  }) {
    return showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.85),
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (ctx, a, b) => MoodboardAnnotateOverlay(
        bibleId: bibleId,
        image: image,
        sceneLabel: sceneLabel,
        onClose: () => Navigator.of(ctx).pop(),
      ),
    );
  }

  @override
  ConsumerState<MoodboardAnnotateOverlay> createState() =>
      _MoodboardAnnotateOverlayState();
}

class _MoodboardAnnotateOverlayState
    extends ConsumerState<MoodboardAnnotateOverlay> {
  final _commentCtrl = TextEditingController();
  final List<MoodboardStroke> _strokes = [];
  Set<int> _resolved = {};
  _AnnotateTool _tool = _AnnotateTool.draw;
  Color _drawColor = const Color(0xFF2997FF);
  List<Offset> _livePoints = [];
  Offset? _arrowStart;
  Offset? _arrowEnd;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final strokes =
        await MoodboardAnnotationStore.loadStrokes(widget.image.id);
    final resolved =
        await MoodboardAnnotationStore.loadResolved(widget.image.id);
    if (!mounted) return;
    setState(() {
      _strokes
        ..clear()
        ..addAll(strokes);
      _resolved = resolved;
      _loading = false;
    });
  }

  Future<void> _persistStrokes() async {
    await MoodboardAnnotationStore.saveStrokes(widget.image.id, _strokes);
  }

  void _undo() {
    if (_strokes.isEmpty) return;
    setState(() => _strokes.removeLast());
    _persistStrokes();
  }

  void _onPanStart(Offset local, Size size) {
    if (_tool == _AnnotateTool.none || _tool == _AnnotateTool.text) return;
    final n = Offset(local.dx / size.width, local.dy / size.height);
    setState(() {
      if (_tool == _AnnotateTool.draw) {
        _livePoints = [n];
      } else if (_tool == _AnnotateTool.arrow) {
        _arrowStart = n;
        _arrowEnd = n;
      }
    });
  }

  void _onPanUpdate(Offset local, Size size) {
    final n = Offset(
      (local.dx / size.width).clamp(0.0, 1.0),
      (local.dy / size.height).clamp(0.0, 1.0),
    );
    setState(() {
      if (_tool == _AnnotateTool.draw) {
        _livePoints = [..._livePoints, n];
      } else if (_tool == _AnnotateTool.arrow) {
        _arrowEnd = n;
      }
    });
  }

  void _onPanEnd() {
    if (_tool == _AnnotateTool.draw && _livePoints.length >= 2) {
      _strokes.add(
        MoodboardStroke(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          color: _drawColor,
          width: 3,
          points: List.of(_livePoints),
        ),
      );
      _livePoints = [];
      _persistStrokes();
    } else if (_tool == _AnnotateTool.arrow &&
        _arrowStart != null &&
        _arrowEnd != null) {
      _strokes.add(
        MoodboardStroke(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          color: _drawColor,
          width: 4,
          points: [_arrowStart!, _arrowEnd!],
          label: 'ARROW',
        ),
      );
      _arrowStart = null;
      _arrowEnd = null;
      _persistStrokes();
    } else {
      setState(() {
        _livePoints = [];
        _arrowStart = null;
        _arrowEnd = null;
      });
    }
    setState(() {});
  }

  Future<void> _addTextLabel(Size size, Offset local) async {
    final text = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final c = TextEditingController();
        return AlertDialog(
          title: const Text('Etiqueta'),
          content: TextField(
            controller: c,
            autofocus: true,
            decoration: const InputDecoration(hintText: 'KEY FLICKER…'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, c.text.trim()),
              child: const Text('Añadir'),
            ),
          ],
        );
      },
    );
    if (text == null || text.isEmpty) return;
    final n = Offset(local.dx / size.width, local.dy / size.height);
    setState(() {
      _strokes.add(
        MoodboardStroke(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          color: _drawColor,
          width: 2,
          points: [n],
          label: text,
        ),
      );
    });
    await _persistStrokes();
  }

  Future<void> _sendComment() async {
    final text = _commentCtrl.text.trim();
    if (text.isEmpty) return;
    final db = ref.read(databaseProvider);
    await db.insertBibleComment(
      BibleCommentsCompanion.insert(
        bibleId: widget.bibleId,
        authorRole: 'dp',
        targetType: 'moodboard',
        targetId: Value(widget.image.id),
        comment: text,
      ),
    );
    _commentCtrl.clear();
  }

  Future<void> _toggleResolved(int commentId) async {
    setState(() {
      if (_resolved.contains(commentId)) {
        _resolved.remove(commentId);
      } else {
        _resolved.add(commentId);
      }
    });
    await MoodboardAnnotationStore.saveResolved(widget.image.id, _resolved);
  }

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final db = ref.watch(databaseProvider);

    return Material(
      color: const Color(0xFF0A0A0C),
      child: wide
          ? Row(
              children: [
                Expanded(child: _buildCanvas(palette)),
                SizedBox(width: 360, child: _buildSidebar(db, palette)),
              ],
            )
          : Column(
              children: [
                Expanded(flex: 55, child: _buildCanvas(palette)),
                Expanded(flex: 45, child: _buildSidebar(db, palette)),
              ],
            ),
    );
  }

  Widget _buildCanvas(AppPalette palette) {
    return Stack(
      children: [
        Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final size = Size(constraints.maxWidth, constraints.maxHeight);
                  return DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.06),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.5),
                          blurRadius: 40,
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.file(
                            File(widget.image.imagePath),
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => ColoredBox(
                              color: palette.surfaceElevated,
                              child: const Icon(Icons.broken_image_outlined),
                            ),
                          ),
                          if (!_loading)
                            GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTapUp: _tool == _AnnotateTool.text
                                  ? (d) =>
                                      _addTextLabel(size, d.localPosition)
                                  : null,
                              onPanStart: _tool == _AnnotateTool.draw ||
                                      _tool == _AnnotateTool.arrow
                                  ? (d) =>
                                      _onPanStart(d.localPosition, size)
                                  : null,
                              onPanUpdate: _tool == _AnnotateTool.draw ||
                                      _tool == _AnnotateTool.arrow
                                  ? (d) =>
                                      _onPanUpdate(d.localPosition, size)
                                  : null,
                              onPanEnd: _tool == _AnnotateTool.draw ||
                                      _tool == _AnnotateTool.arrow
                                  ? (_) => _onPanEnd()
                                  : null,
                              child: CustomPaint(
                                painter: _AnnotationPainter(
                                  strokes: [
                                    ..._strokes,
                                    if (_livePoints.length >= 2)
                                      MoodboardStroke(
                                        id: 'live',
                                        color: _drawColor,
                                        width: 3,
                                        points: _livePoints,
                                      ),
                                    if (_arrowStart != null &&
                                        _arrowEnd != null)
                                      MoodboardStroke(
                                        id: 'live-arrow',
                                        color: _drawColor,
                                        width: 4,
                                        points: [_arrowStart!, _arrowEnd!],
                                        label: 'ARROW',
                                      ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
        // Toolbar
        Positioned(
          left: 20,
          top: 0,
          bottom: 0,
          child: Center(
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xB31A1A1C),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _ToolBtn(
                    icon: Icons.draw,
                    selected: _tool == _AnnotateTool.draw,
                    onTap: () => setState(() {
                      _tool = _AnnotateTool.draw;
                      _drawColor = const Color(0xFF2997FF);
                    }),
                    palette: palette,
                  ),
                  _ToolBtn(
                    icon: Icons.north_east,
                    selected: _tool == _AnnotateTool.arrow,
                    onTap: () => setState(() {
                      _tool = _AnnotateTool.arrow;
                      _drawColor = const Color(0xFF2997FF);
                    }),
                    palette: palette,
                  ),
                  _ToolBtn(
                    icon: Icons.title,
                    selected: _tool == _AnnotateTool.text,
                    onTap: () => setState(() {
                      _tool = _AnnotateTool.text;
                      _drawColor = const Color(0xFFFF3B30);
                    }),
                    palette: palette,
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Container(
                      height: 1,
                      width: 28,
                      color: Colors.white.withValues(alpha: 0.1),
                    ),
                  ),
                  _ToolBtn(
                    icon: Icons.undo,
                    selected: false,
                    onTap: _undo,
                    palette: palette,
                    danger: true,
                  ),
                ],
              ),
            ),
          ),
        ),
        // Status bar
        Positioned(
          left: 0,
          right: 0,
          bottom: 24,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xB31A1A1C),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Color(0xFFFFB4AB),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'ANNOTATE',
                    style: AppTypography.mono(palette).copyWith(fontSize: 12),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Container(
                      width: 1,
                      height: 14,
                      color: Colors.white.withValues(alpha: 0.2),
                    ),
                  ),
                  Text(
                    widget.sceneLabel?.trim().isNotEmpty == true
                        ? widget.sceneLabel!
                        : (widget.image.filmReference ??
                            widget.image.caption ??
                            'Moodboard reference'),
                    style: AppTypography.mono(palette).copyWith(
                      fontSize: 12,
                      color: palette.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          top: 16,
          right: 16,
          child: IconButton.filledTonal(
            onPressed: widget.onClose,
            icon: const Icon(Icons.close),
          ),
        ),
      ],
    );
  }

  Widget _buildSidebar(AppDatabase db, AppPalette palette) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xB31A1A1C),
        border: Border(
          left: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
        ),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              children: [
                Text(
                  'Annotations',
                  style: AppTypography.titleMedium(palette).copyWith(
                    fontSize: 15,
                  ),
                ),
                const Spacer(),
                StreamBuilder<List<BibleComment>>(
                  stream: db.watchBibleComments(
                    widget.bibleId,
                    targetType: 'moodboard',
                    targetId: widget.image.id,
                  ),
                  builder: (context, snap) {
                    final unresolved = (snap.data ?? [])
                        .where((c) => !_resolved.contains(c.id))
                        .length;
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: palette.surfaceElevated,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '$unresolved Unresolved',
                        style: AppTypography.mono(palette).copyWith(
                          fontSize: 11,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          Divider(height: 1, color: Colors.white.withValues(alpha: 0.05)),
          Expanded(
            child: StreamBuilder<List<BibleComment>>(
              stream: db.watchBibleComments(
                widget.bibleId,
                targetType: 'moodboard',
                targetId: widget.image.id,
              ),
              builder: (context, snap) {
                final comments = snap.data ?? [];
                if (comments.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'Sin anotaciones aún.\nDibuja en la imagen o escribe abajo.',
                        textAlign: TextAlign.center,
                        style: AppTypography.bodyMedium(palette),
                      ),
                    ),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: comments.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 16),
                  itemBuilder: (context, i) {
                    final c = comments[i];
                    final resolved = _resolved.contains(c.id);
                    return _CommentTile(
                      comment: c,
                      resolved: resolved,
                      onToggleResolve: () => _toggleResolved(c.id),
                      palette: palette,
                    );
                  },
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.25),
              border: Border(
                top: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
              ),
            ),
            child: Stack(
              children: [
                TextField(
                  controller: _commentCtrl,
                  maxLines: 3,
                  minLines: 2,
                  style: AppTypography.bodyMedium(palette).copyWith(
                    color: palette.textPrimary,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Add a note or reply…',
                    hintStyle: AppTypography.caption(palette),
                    filled: true,
                    fillColor: palette.surfaceElevated,
                    contentPadding: const EdgeInsets.fromLTRB(12, 12, 48, 36),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: Colors.white.withValues(alpha: 0.1),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: Colors.white.withValues(alpha: 0.1),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: palette.accent.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  right: 8,
                  bottom: 8,
                  child: Material(
                    color: const Color(0xFF2997FF),
                    borderRadius: BorderRadius.circular(6),
                    child: InkWell(
                      onTap: _sendComment,
                      borderRadius: BorderRadius.circular(6),
                      child: const SizedBox(
                        width: 28,
                        height: 28,
                        child: Icon(Icons.send, size: 14, color: Color(0xFF002E57)),
                      ),
                    ),
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

class _ToolBtn extends StatelessWidget {
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  final AppPalette palette;
  final bool danger;

  const _ToolBtn({
    required this.icon,
    required this.selected,
    required this.onTap,
    required this.palette,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = danger
        ? palette.error
        : selected
            ? palette.accent
            : palette.textTertiary;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: selected
            ? palette.accent.withValues(alpha: 0.12)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            width: 40,
            height: 40,
            child: Icon(icon, color: color, size: 20),
          ),
        ),
      ),
    );
  }
}

class _CommentTile extends StatelessWidget {
  final BibleComment comment;
  final bool resolved;
  final VoidCallback onToggleResolve;
  final AppPalette palette;

  const _CommentTile({
    required this.comment,
    required this.resolved,
    required this.onToggleResolve,
    required this.palette,
  });

  String get _roleLabel => switch (comment.authorRole) {
        'dp' => 'DP',
        'gaffer' => 'Gaffer',
        'colorist' => 'Colorist',
        'director' || 'dir' => 'Director',
        _ => comment.authorRole.toUpperCase(),
      };

  @override
  Widget build(BuildContext context) {
    final isDp = comment.authorRole == 'dp';
    return Opacity(
      opacity: resolved ? 0.45 : 1,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isDp
                  ? palette.accent.withValues(alpha: 0.2)
                  : palette.surfaceElevated,
              border: Border.all(
                color: isDp
                    ? palette.accent.withValues(alpha: 0.35)
                    : Colors.white.withValues(alpha: 0.1),
              ),
            ),
            child: resolved
                ? Icon(Icons.check, size: 14, color: palette.textTertiary)
                : Text(
                    _roleLabel.length > 3
                        ? _roleLabel.substring(0, 3)
                        : _roleLabel,
                    style: AppTypography.label(palette).copyWith(
                      fontSize: 9,
                      color: isDp ? palette.accent : palette.textSecondary,
                    ),
                  ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      isDp ? 'You' : _roleLabel,
                      style: AppTypography.label(palette).copyWith(
                        color: isDp ? palette.accent : palette.textPrimary,
                        decoration:
                            resolved ? TextDecoration.lineThrough : null,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _formatTime(comment.createdAt),
                      style: AppTypography.mono(palette).copyWith(
                        fontSize: 10,
                        color: palette.textTertiary,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      tooltip: resolved ? 'Reabrir' : 'Resolver',
                      onPressed: onToggleResolve,
                      visualDensity: VisualDensity.compact,
                      icon: Icon(
                        resolved
                            ? Icons.replay
                            : Icons.check_circle_outline,
                        size: 16,
                        color: palette.textTertiary,
                      ),
                    ),
                  ],
                ),
                Text(
                  comment.comment,
                  style: AppTypography.bodyMedium(palette).copyWith(
                    color: palette.textSecondary,
                    fontSize: 13,
                    height: 1.4,
                    decoration: resolved ? TextDecoration.lineThrough : null,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final sameDay =
        dt.year == now.year && dt.month == now.month && dt.day == now.day;
    if (sameDay) {
      final h = dt.hour.toString().padLeft(2, '0');
      final m = dt.minute.toString().padLeft(2, '0');
      return '$h:$m';
    }
    return '${dt.day}/${dt.month}';
  }
}

class _AnnotationPainter extends CustomPainter {
  final List<MoodboardStroke> strokes;

  _AnnotationPainter({required this.strokes});

  @override
  void paint(Canvas canvas, Size size) {
    for (final s in strokes) {
      if (s.points.isEmpty) continue;
      final paint = Paint()
        ..color = s.color
        ..strokeWidth = s.width
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;

      if (s.label == 'ARROW' && s.points.length >= 2) {
        final a = Offset(
          s.points.first.dx * size.width,
          s.points.first.dy * size.height,
        );
        final b = Offset(
          s.points.last.dx * size.width,
          s.points.last.dy * size.height,
        );
        paint.strokeWidth = s.width;
        canvas.drawLine(a, b, paint);
        final angle = math.atan2(b.dy - a.dy, b.dx - a.dx);
        const head = 12.0;
        final p1 = Offset(
          b.dx - head * math.cos(angle - 0.4),
          b.dy - head * math.sin(angle - 0.4),
        );
        final p2 = Offset(
          b.dx - head * math.cos(angle + 0.4),
          b.dy - head * math.sin(angle + 0.4),
        );
        final path = Path()
          ..moveTo(b.dx, b.dy)
          ..lineTo(p1.dx, p1.dy)
          ..moveTo(b.dx, b.dy)
          ..lineTo(p2.dx, p2.dy);
        canvas.drawPath(path, paint);
        continue;
      }

      if (s.label != null && s.label != 'ARROW' && s.points.length == 1) {
        final o = Offset(
          s.points.first.dx * size.width,
          s.points.first.dy * size.height,
        );
        final tp = TextPainter(
          text: TextSpan(
            text: s.label,
            style: TextStyle(
              color: s.color,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, o);
        continue;
      }

      if (s.points.length < 2) continue;
      final path = Path()
        ..moveTo(
          s.points.first.dx * size.width,
          s.points.first.dy * size.height,
        );
      for (var i = 1; i < s.points.length; i++) {
        path.lineTo(
          s.points[i].dx * size.width,
          s.points[i].dy * size.height,
        );
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _AnnotationPainter oldDelegate) => true;
}
