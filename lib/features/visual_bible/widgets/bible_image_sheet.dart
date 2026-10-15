import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/annotations/annotation_canvas.dart';
import '../../../shared/annotations/annotation_document.dart';
import '../../../shared/visual_bible/bible_cards.dart';
import '../../../shared/visual_bible/lighting_metrics.dart';
import '../moodboard_annotation_store.dart';
import 'bible_point_panel.dart';
import 'lighting/lighting_metrics_widget.dart';

/// Una imagen de una tarjeta como lámina: la imagen con su dibujo encima,
/// y a su lado qué cuenta, su luz y cuántos comentarios tiene. Tocar la
/// imagen la abre en el visor para comentarla y dibujar con el Pencil.
class BibleImageSheet extends ConsumerStatefulWidget {
  final int index;
  final int count;
  final int imageId;
  final String path;
  final BibleImageNote note;
  final bool isCover;
  final bool showDrawing;
  final int? bibleId;
  final int? projectId;

  /// Abre el visor (comentarios y dibujo); al volver, se relee el dibujo.
  final Future<void> Function() onOpen;

  /// [now]: guardar ya (luz) y no tras la pausa de escritura.
  final void Function(BibleImageNote note, {bool now}) onChanged;
  final VoidCallback onCover;
  final VoidCallback onRemove;

  const BibleImageSheet({
    super.key,
    required this.index,
    required this.count,
    required this.imageId,
    required this.path,
    required this.note,
    required this.isCover,
    required this.showDrawing,
    required this.onOpen,
    required this.onChanged,
    required this.onCover,
    required this.onRemove,
    this.bibleId,
    this.projectId,
  });

  @override
  ConsumerState<BibleImageSheet> createState() => _BibleImageSheetState();
}

class _BibleImageSheetState extends ConsumerState<BibleImageSheet> {
  late final _title = TextEditingController(text: widget.note.title);
  late final _text = TextEditingController(text: widget.note.text);
  late BibleImageNote _note = widget.note;
  Future<AnnotationDocument>? _drawing;
  double? _aspect;

  @override
  void initState() {
    super.initState();
    _loadDrawing();
    // La proporción de la imagen: el dibujo se encaja sobre ella.
    final stream = FileImage(
      File(widget.path),
    ).resolve(const ImageConfiguration());
    stream.addListener(
      ImageStreamListener((info, _) {
        if (!mounted) return;
        setState(() => _aspect = info.image.width / info.image.height);
      }, onError: (_, _) {}),
    );
  }

  void _loadDrawing() {
    final projectId = widget.projectId;
    if (projectId == null) return;
    _drawing = MoodboardAnnotationStore.loadDocument(
      db: ref.read(databaseProvider),
      projectId: projectId,
      imageId: widget.imageId,
    );
  }

  @override
  void dispose() {
    _title.dispose();
    _text.dispose();
    super.dispose();
  }

  void _change(BibleImageNote next, {bool now = false}) {
    _note = next;
    widget.onChanged(next, now: now);
  }

  Future<void> _open() async {
    await widget.onOpen();
    if (!mounted) return;
    setState(_loadDrawing);
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final label = BiblePointPanel.labelStyle(palette);
    final bodyStyle = AppTypography.bodyLarge(palette).copyWith(height: 1.55);

    final image = _ImageWithDrawing(
      path: widget.path,
      aspect: _aspect,
      drawing: widget.showDrawing ? _drawing : null,
      onTap: _open,
    );

    final tools = Wrap(
      spacing: AppSpacing.sm,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        FilledButton.tonalIcon(
          onPressed: _open,
          icon: const Icon(Icons.draw_outlined, size: 16),
          label: const Text('Comentar y dibujar'),
        ),
        if (widget.bibleId != null)
          StreamBuilder<List<BibleComment>>(
            stream: ref
                .watch(databaseProvider)
                .watchBibleComments(
                  widget.bibleId!,
                  targetType: 'moodboard',
                  targetId: widget.imageId,
                ),
            builder: (context, snap) {
              final n = snap.data?.length ?? 0;
              return Text(
                n == 0
                    ? 'Sin comentarios'
                    : '$n comentario${n == 1 ? '' : 's'}',
                style: AppTypography.caption(palette),
              );
            },
          ),
        FutureBuilder<AnnotationDocument>(
          future: _drawing,
          builder: (context, snap) {
            final doc = snap.data;
            if (doc == null || doc.isEmpty) return const SizedBox.shrink();
            return Text(
              widget.showDrawing ? '· con dibujo' : '· dibujo oculto',
              style: AppTypography.caption(palette),
            );
          },
        ),
      ],
    );

    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'LÁMINA ${widget.index + 1} DE ${widget.count}'
                '${widget.isCover ? ' · PORTADA' : ''}',
                style: label,
              ),
            ),
            if (!widget.isCover)
              IconButton(
                tooltip: 'Poner de portada',
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.star_border, size: 18),
                onPressed: widget.onCover,
              ),
            IconButton(
              tooltip: 'Quitar esta imagen de la tarjeta',
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.close, size: 18),
              onPressed: widget.onRemove,
            ),
          ],
        ),
        TextField(
          controller: _title,
          style: AppTypography.titleMedium(palette),
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            isDense: true,
            border: InputBorder.none,
            hintText:
                'Título de la lámina: «Medio rostro quemado por el sodio»',
            hintStyle: AppTypography.titleMedium(
              palette,
            ).copyWith(color: palette.textTertiary),
          ),
          onChanged: (v) => _change(_note.copyWith(title: v.trim())),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text('QUÉ CONTAMOS CON ESTA IMAGEN', style: label),
        TextField(
          controller: _text,
          minLines: 3,
          maxLines: null,
          style: bodyStyle,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            isDense: true,
            border: InputBorder.none,
            hintText:
                'Qué nos llevamos de ella: dirección de la luz, calidad, '
                'temperatura, qué se ve y qué se pierde…',
            hintStyle: bodyStyle.copyWith(color: palette.textTertiary),
          ),
          onChanged: (v) => _change(_note.copyWith(text: v.trim())),
        ),
        const SizedBox(height: AppSpacing.md),
        Text('SU LUZ', style: label),
        const SizedBox(height: 6),
        LightingMetricsWidget(
          value: LightingMetrics.fromJson(_note.light),
          compact: true,
          onChanged: (next) {
            setState(() {});
            _change(_note.copyWith(light: next.encode()), now: true);
          },
        ),
      ],
    );

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BiblePointPanel.decoration(palette),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 760;
          if (!wide) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                image,
                const SizedBox(height: AppSpacing.sm),
                tools,
                const SizedBox(height: AppSpacing.md),
                text,
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    image,
                    const SizedBox(height: AppSpacing.sm),
                    tools,
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.lg),
              Expanded(flex: 2, child: text),
            ],
          );
        },
      ),
    );
  }
}

/// La imagen con lo dibujado encima, encajado a su proporción.
class _ImageWithDrawing extends StatelessWidget {
  final String path;
  final double? aspect;
  final Future<AnnotationDocument>? drawing;
  final VoidCallback onTap;

  const _ImageWithDrawing({
    required this.path,
    required this.aspect,
    required this.drawing,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Abrir para comentar y dibujar',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: AspectRatio(
            aspectRatio: aspect ?? 16 / 9,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.file(File(path), fit: BoxFit.cover, cacheWidth: 1400),
                if (drawing != null)
                  FutureBuilder<AnnotationDocument>(
                    future: drawing,
                    builder: (context, snap) {
                      final doc = snap.data;
                      if (doc == null || doc.isEmpty) {
                        return const SizedBox.shrink();
                      }
                      return IgnorePointer(
                        child: CustomPaint(
                          painter: AnnotationPainter(document: doc),
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
