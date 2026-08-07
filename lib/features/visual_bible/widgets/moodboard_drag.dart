import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// Datos arrastrados desde una imagen del moodboard.
class MoodboardDragPayload {
  final String imagePath;
  final int? moodboardImageId;
  final String? caption;
  final String? filmReference;

  const MoodboardDragPayload({
    required this.imagePath,
    this.moodboardImageId,
    this.caption,
    this.filmReference,
  });

  Future<Uint8List?> readBytes() async {
    final file = File(imagePath);
    if (!await file.exists()) return null;
    return file.readAsBytes();
  }

  String? get suggestedCaption {
    if (caption != null && caption!.trim().isNotEmpty) return caption!.trim();
    if (filmReference != null && filmReference!.trim().isNotEmpty) {
      return filmReference!.trim();
    }
    return null;
  }
}

/// Miniatura del moodboard arrastrable a zonas de la biblia.
class MoodboardDraggableThumb extends StatelessWidget {
  final MoodboardDragPayload payload;
  final double width;
  final double height;

  const MoodboardDraggableThumb({
    super.key,
    required this.payload,
    this.width = 120,
    this.height = 88,
  });

  @override
  Widget build(BuildContext context) {
    final file = File(payload.imagePath);
    final thumb = ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: file.existsSync()
          ? Image.file(file, width: width, height: height, fit: BoxFit.cover)
          : Container(
              width: width,
              height: height,
              color: context.palette.surfaceOverlay,
              alignment: Alignment.center,
              child: Icon(
                Icons.broken_image_outlined,
                color: context.palette.textTertiary,
              ),
            ),
    );

    return LongPressDraggable<MoodboardDragPayload>(
      data: payload,
      feedback: Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(8),
        clipBehavior: Clip.hardEdge,
        child: Opacity(
          opacity: 0.92,
          child: file.existsSync()
              ? Image.file(file, width: width, height: height, fit: BoxFit.cover)
              : SizedBox(width: width, height: height),
        ),
      ),
      childWhenDragging: Opacity(opacity: 0.35, child: thumb),
      child: Stack(
        children: [
          thumb,
          Positioned(
            right: 4,
            bottom: 4,
            child: Icon(
              Icons.drag_indicator,
              size: 14,
              color: Colors.white.withValues(alpha: 0.85),
            ),
          ),
        ],
      ),
    );
  }
}

/// Zona de drop: acepta refs del moodboard y bytes (arrastre interno).
class BibleImageDropZone extends StatefulWidget {
  final Widget child;
  final Future<void> Function(Uint8List bytes, String? name)? onBytesDropped;
  final Future<void> Function(MoodboardDragPayload payload)? onMoodboardDropped;

  const BibleImageDropZone({
    super.key,
    required this.child,
    this.onBytesDropped,
    this.onMoodboardDropped,
  });

  @override
  State<BibleImageDropZone> createState() => _BibleImageDropZoneState();
}

class _BibleImageDropZoneState extends State<BibleImageDropZone> {
  bool _moodboardOver = false;
  bool _bytesOver = false;

  Widget _decorated({required bool highlight}) {
    final palette = context.palette;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      decoration: BoxDecoration(
        border: highlight
            ? Border.all(color: palette.accent, width: 2)
            : null,
        borderRadius: BorderRadius.circular(8),
      ),
      child: widget.child,
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget content = _decorated(
      highlight: _moodboardOver || _bytesOver,
    );

    if (widget.onBytesDropped != null) {
      content = DragTarget<Uint8List>(
        onWillAcceptWithDetails: (_) {
          setState(() => _bytesOver = true);
          return true;
        },
        onLeave: (_) => setState(() => _bytesOver = false),
        onAcceptWithDetails: (details) async {
          setState(() => _bytesOver = false);
          await widget.onBytesDropped!(details.data, null);
        },
        builder: (context, candidate, _) => _decorated(
          highlight: _moodboardOver || _bytesOver || candidate.isNotEmpty,
        ),
      );
    }

    if (widget.onMoodboardDropped != null) {
      content = DragTarget<MoodboardDragPayload>(
        onWillAcceptWithDetails: (_) {
          setState(() => _moodboardOver = true);
          return true;
        },
        onLeave: (_) => setState(() => _moodboardOver = false),
        onAcceptWithDetails: (details) async {
          setState(() => _moodboardOver = false);
          await widget.onMoodboardDropped!(details.data);
        },
        builder: (context, candidate, _) {
          if (widget.onBytesDropped != null) {
            return DragTarget<Uint8List>(
              onWillAcceptWithDetails: (_) {
                setState(() => _bytesOver = true);
                return true;
              },
              onLeave: (_) => setState(() => _bytesOver = false),
              onAcceptWithDetails: (details) async {
                setState(() => _bytesOver = false);
                await widget.onBytesDropped!(details.data, null);
              },
              builder: (context, bytesCandidate, __) => _decorated(
                highlight: _moodboardOver ||
                    _bytesOver ||
                    candidate.isNotEmpty ||
                    bytesCandidate.isNotEmpty,
              ),
            );
          }
          return _decorated(
            highlight: _moodboardOver || candidate.isNotEmpty,
          );
        },
      );
    }

    return content;
  }
}

/// Compatibilidad: acepta `onImageDropped` como alias de `onBytesDropped`.
class ImageDropZone extends BibleImageDropZone {
  const ImageDropZone({
    super.key,
    required super.child,
    required Future<void> Function(Uint8List bytes, String? name) onImageDropped,
    super.onMoodboardDropped,
  }) : super(onBytesDropped: onImageDropped);
}
