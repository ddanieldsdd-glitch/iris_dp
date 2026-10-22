import 'dart:convert';
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
import 'bible_point_images.dart';
import 'bible_point_panel.dart';
import 'moodboard_images_viewer.dart';
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

  /// Una imagen sola (el widget «Análisis de una imagen»): sin portada, y
  /// «cambiar» en lugar de «quitar».
  final bool single;

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
    this.single = false,
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
                widget.single
                    ? 'ANÁLISIS DE LA IMAGEN'
                    : 'LÁMINA ${widget.index + 1} DE ${widget.count}'
                          '${widget.isCover ? ' · PORTADA' : ''}',
                style: label,
              ),
            ),
            if (!widget.isCover && !widget.single)
              IconButton(
                tooltip: 'Poner de portada',
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.star_border, size: 18),
                onPressed: widget.onCover,
              ),
            IconButton(
              tooltip: widget.single
                  ? 'Cambiar la imagen'
                  : 'Quitar esta imagen de la tarjeta',
              visualDensity: VisualDensity.compact,
              icon: Icon(
                widget.single ? Icons.swap_horiz : Icons.close,
                size: 18,
              ),
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
          child: _box(
            Stack(
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

  Widget _box(Widget child) =>
      AspectRatio(aspectRatio: aspect ?? 16 / 9, child: child);
}

/// Miniatura de una imagen del moodboard con su dibujo encima y cuántos
/// comentarios tiene. Tocarla abre el visor.
class MoodboardImageThumb extends ConsumerStatefulWidget {
  final int imageId;
  final String path;
  final int? projectId;
  final int? bibleId;
  final double width;
  final double height;

  /// Abre el visor; al volver, se relee el dibujo.
  final Future<void> Function() onTap;

  const MoodboardImageThumb({
    super.key,
    required this.imageId,
    required this.path,
    required this.onTap,
    this.projectId,
    this.bibleId,
    this.width = 120,
    this.height = 68,
  });

  @override
  ConsumerState<MoodboardImageThumb> createState() =>
      _MoodboardImageThumbState();
}

class _MoodboardImageThumbState extends ConsumerState<MoodboardImageThumb> {
  Future<AnnotationDocument>? _drawing;
  double? _aspect;

  @override
  void initState() {
    super.initState();
    _load();
    // Con su proporción, el dibujo cae donde se hizo.
    FileImage(File(widget.path))
        .resolve(const ImageConfiguration())
        .addListener(
          ImageStreamListener((info, _) {
            if (!mounted) return;
            setState(() => _aspect = info.image.width / info.image.height);
          }, onError: (_, _) {}),
        );
  }

  void _load() {
    final projectId = widget.projectId;
    if (projectId == null) return;
    _drawing = MoodboardAnnotationStore.loadDocument(
      db: ref.read(databaseProvider),
      projectId: projectId,
      imageId: widget.imageId,
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ColoredBox(
            color: Colors.black,
            child: Center(
              child: _ImageWithDrawing(
                path: widget.path,
                aspect: _aspect,
                drawing: _drawing,
                onTap: () async {
                  await widget.onTap();
                  if (mounted) setState(_load);
                },
              ),
            ),
          ),
          if (widget.bibleId != null)
            Positioned(
              left: 4,
              bottom: 4,
              child: StreamBuilder<List<BibleComment>>(
                stream: ref
                    .watch(databaseProvider)
                    .watchBibleComments(
                      widget.bibleId!,
                      targetType: 'moodboard',
                      targetId: widget.imageId,
                    ),
                builder: (context, snap) {
                  final n = snap.data?.length ?? 0;
                  if (n == 0) return const SizedBox.shrink();
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '💬 $n',
                      style: const TextStyle(fontSize: 10, color: Colors.white),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

/// «Análisis de una imagen»: una sola imagen estudiada a fondo — su título,
/// qué cuenta, su luz, sus comentarios y su dibujo. Valor: JSON con
/// `image` (id del moodboard) y la nota.
class BibleImageAnalysisPoint extends ConsumerWidget {
  final int projectId;
  final int bibleId;
  final String sectionId;
  final String? value;
  final ValueChanged<String?> onChanged;

  const BibleImageAnalysisPoint({
    super.key,
    required this.projectId,
    required this.bibleId,
    required this.sectionId,
    required this.value,
    required this.onChanged,
  });

  static (int?, BibleImageNote) decode(String? raw) {
    if (raw == null || raw.trim().isEmpty)
      return (null, const BibleImageNote());
    try {
      final map = jsonDecode(raw);
      if (map is! Map) return (null, const BibleImageNote());
      return ((map['image'] as num?)?.toInt(), BibleImageNote.fromJson(map));
    } catch (_) {
      return (null, const BibleImageNote());
    }
  }

  static String encode(int? image, BibleImageNote note) =>
      jsonEncode({if (image != null) 'image': image, ...note.toJson()});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final (imageId, note) = decode(value);

    Future<void> pick() async {
      final picked = await showMoodboardImagePicker(
        context,
        projectId: projectId,
        bibleId: bibleId,
        sectionId: sectionId,
        selected: [?imageId],
        single: true,
      );
      if (picked == null || picked.isEmpty) return;
      onChanged(encode(picked.first, note));
    }

    if (imageId == null) {
      return InkWell(
        onTap: pick,
        borderRadius: BorderRadius.circular(BiblePointPanel.radius),
        child: Container(
          height: 180,
          decoration: BiblePointPanel.decoration(palette),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.image_search_outlined,
                size: 32,
                color: palette.textSecondary,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'ELIGE LA IMAGEN QUE ANALIZAMOS',
                style: BiblePointPanel.labelStyle(palette),
              ),
            ],
          ),
        ),
      );
    }

    return StreamBuilder<List<MoodboardImage>>(
      stream: ref.watch(databaseProvider).watchMoodboardImages(projectId),
      builder: (context, snap) {
        final row = snap.data?.where((m) => m.id == imageId).firstOrNull;
        if (row == null) return const SizedBox(height: 180);
        return BibleImageSheet(
          key: ValueKey('analysis_$imageId'),
          index: 0,
          count: 1,
          imageId: imageId,
          path: row.imagePath,
          note: note,
          isCover: false,
          showDrawing: true,
          single: true,
          bibleId: bibleId,
          projectId: projectId,
          onOpen: () => openMoodboardImages(
            context,
            [imageId],
            initialId: imageId,
            bibleId: bibleId,
          ),
          onChanged: (next, {bool now = false}) =>
              onChanged(encode(imageId, next)),
          onCover: () {},
          onRemove: pick,
        );
      },
    );
  }
}
