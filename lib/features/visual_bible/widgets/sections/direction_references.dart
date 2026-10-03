import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/database/database_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/visual_bible/bible_section_ids.dart';
import '../../../../shared/visual_bible/direction_reference.dart';
import '../bible_point_panel.dart';

/// Referencias de dirección: fichas que explican por qué se cita una obra y
/// para qué, con imagen opcional.
class DirectionReferencesPanel extends ConsumerWidget {
  final int projectId;
  final List<DirectionReference> references;
  final ValueChanged<List<DirectionReference>> onChanged;
  final VoidCallback onAddImage;
  final VoidCallback onOpenMoodboard;

  const DirectionReferencesPanel({
    super.key,
    required this.projectId,
    required this.references,
    required this.onChanged,
    required this.onAddImage,
    required this.onOpenMoodboard,
  });

  Future<void> _edit(
    BuildContext context,
    List<MoodboardImage> images, {
    int? index,
    int? imageId,
  }) async {
    final initial = index != null
        ? references[index]
        : DirectionReference(imageId: imageId);
    final resolved = index == null
        ? imageId
        : DirectionReference.resolveImages(
            references,
            images.map((i) => i.id).toList(),
          )[index];
    final result = await showDialog<_ReferenceEdit>(
      context: context,
      builder: (_) => _ReferenceDialog(
        initial: initial,
        initialImageId: resolved,
        images: images,
        canDelete: index != null,
      ),
    );
    if (result == null) return;
    final next = [...references];
    if (result.delete) {
      if (index != null) next.removeAt(index);
    } else if (index != null) {
      next[index] = result.reference!;
    } else {
      next.add(result.reference!);
    }
    onChanged(next);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final db = ref.watch(databaseProvider);
    return StreamBuilder<List<MoodboardImage>>(
      stream: db.watchMoodboardImagesForSection(
        projectId,
        BibleSectionId.direction,
      ),
      builder: (context, snap) {
        final images = snap.data ?? const <MoodboardImage>[];
        final byId = {for (final image in images) image.id: image};
        final linked = DirectionReference.resolveImages(
          references,
          images.map((i) => i.id).toList(),
        );
        final unlinked =
            images.where((image) => !linked.contains(image.id)).toList();

        return LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 700 ? 2 : 1;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (references.isEmpty)
                  Text(
                    'Añade las obras que guían la película y explica qué '
                    'tomas de cada una: una emoción, una forma de contar, '
                    'un tema, una puesta en escena.',
                    style: AppTypography.bodyMedium(palette).copyWith(
                      color: palette.textSecondary,
                    ),
                  ),
                for (var row = 0; row < references.length; row += columns)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.md),
                    child: IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (var c = 0; c < columns; c++) ...[
                            if (c > 0) const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: row + c < references.length
                                  ? _ReferenceCard(
                                      reference: references[row + c],
                                      image: byId[linked[row + c]],
                                      onTap: () => _edit(
                                        context,
                                        images,
                                        index: row + c,
                                      ),
                                    )
                                  : const SizedBox.shrink(),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                if (unlinked.isNotEmpty) ...[
                  Text(
                    'IMÁGENES SIN FICHA · TOCA UNA PARA EXPLICARLA',
                    style: BiblePointPanel.labelStyle(palette),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: [
                      for (final image in unlinked)
                        InkWell(
                          onTap: () =>
                              _edit(context, images, imageId: image.id),
                          borderRadius: BorderRadius.circular(6),
                          child: _Thumbnail(path: image.imagePath, width: 128),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
                Wrap(
                  spacing: AppSpacing.sm,
                  children: [
                    _action(
                      palette,
                      Icons.add,
                      'Añadir referencia',
                      () => _edit(context, images),
                    ),
                    _action(
                      palette,
                      Icons.add_photo_alternate_outlined,
                      'Añadir imagen',
                      onAddImage,
                    ),
                    _action(
                      palette,
                      Icons.grid_view_outlined,
                      'Moodboard',
                      onOpenMoodboard,
                    ),
                  ],
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _action(
    AppPalette palette,
    IconData icon,
    String label,
    VoidCallback onTap,
  ) =>
      TextButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 16, color: palette.textSecondary),
        label: Text(
          label.toUpperCase(),
          style: BiblePointPanel.labelStyle(palette),
        ),
      );
}

class _Thumbnail extends StatelessWidget {
  final String path;
  final double width;

  const _Thumbnail({required this.path, required this.width});

  @override
  Widget build(BuildContext context) {
    final file = File(path);
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: SizedBox(
        width: width,
        height: width * 9 / 16,
        child: file.existsSync()
            ? Image.file(file, fit: BoxFit.cover)
            : ColoredBox(color: context.palette.surfaceOverlay),
      ),
    );
  }
}

class _ReferenceCard extends StatelessWidget {
  final DirectionReference reference;
  final MoodboardImage? image;
  final VoidCallback onTap;

  const _ReferenceCard({
    required this.reference,
    required this.image,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final file = image == null ? null : File(image!.imagePath);
    final label = BiblePointPanel.labelStyle(palette);

    Widget block(String heading, String text, String placeholder) => Padding(
          padding: const EdgeInsets.only(top: AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(heading, style: label.copyWith(fontSize: 10)),
              const SizedBox(height: 4),
              Text(
                text.isEmpty ? placeholder : text,
                style: AppTypography.bodyMedium(palette).copyWith(
                  color:
                      text.isEmpty ? palette.textTertiary : palette.textPrimary,
                  height: 1.45,
                ),
              ),
            ],
          ),
        );

    return Material(
      color: palette.surfaceOverlay.withValues(alpha: 0.45),
      borderRadius: BorderRadius.circular(8),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (file != null && file.existsSync())
              AspectRatio(
                aspectRatio: 16 / 9,
                child: Image.file(file, fit: BoxFit.cover),
              ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (reference.kind.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: palette.accentMuted,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            reference.kind.toUpperCase(),
                            style: label.copyWith(
                              fontSize: 10,
                              color: palette.accent,
                            ),
                          ),
                        ),
                      if (reference.work.isNotEmpty)
                        Text(
                          reference.work.toUpperCase(),
                          style: label.copyWith(fontSize: 10),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    reference.title.isEmpty
                        ? 'Referencia sin título'
                        : reference.title,
                    style: AppTypography.titleMedium(palette),
                  ),
                  block(
                    'POR QUÉ ESTA REFERENCIA',
                    reference.why,
                    'Qué tiene esta obra que nos interesa…',
                  ),
                  block(
                    'PARA QUÉ EN LA PELÍCULA',
                    reference.purpose,
                    'Qué queremos contar o provocar con ella…',
                  ),
                  if (reference.scene.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.md),
                      child: Text(
                        'Momento: ${reference.scene}',
                        style: AppTypography.caption(palette),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReferenceEdit {
  final DirectionReference? reference;
  final bool delete;

  const _ReferenceEdit.save(this.reference) : delete = false;
  const _ReferenceEdit.delete()
      : reference = null,
        delete = true;
}

class _ReferenceDialog extends StatefulWidget {
  final DirectionReference initial;
  final int? initialImageId;
  final List<MoodboardImage> images;
  final bool canDelete;

  const _ReferenceDialog({
    required this.initial,
    required this.initialImageId,
    required this.images,
    required this.canDelete,
  });

  @override
  State<_ReferenceDialog> createState() => _ReferenceDialogState();
}

class _ReferenceDialogState extends State<_ReferenceDialog> {
  late final _work = TextEditingController(text: widget.initial.work);
  late final _title = TextEditingController(text: widget.initial.title);
  late final _why = TextEditingController(text: widget.initial.why);
  late final _purpose = TextEditingController(text: widget.initial.purpose);
  late final _scene = TextEditingController(text: widget.initial.scene);
  late String _kind = widget.initial.kind;
  late int? _imageId = widget.initialImageId;

  @override
  void dispose() {
    for (final c in [_work, _title, _why, _purpose, _scene]) {
      c.dispose();
    }
    super.dispose();
  }

  void _save() {
    Navigator.pop(
      context,
      _ReferenceEdit.save(
        DirectionReference(
          work: _work.text.trim(),
          title: _title.text.trim(),
          kind: _kind,
          why: _why.text.trim(),
          purpose: _purpose.text.trim(),
          scene: _scene.text.trim(),
          imageId: _imageId,
          lens: widget.initial.lens,
          techLabel: widget.initial.techLabel,
          techValue: widget.initial.techValue,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    Widget field(
      TextEditingController controller,
      String label,
      String hint, {
      int maxLines = 1,
    }) =>
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
          child: TextField(
            controller: controller,
            minLines: 1,
            maxLines: maxLines,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: label,
              hintText: hint,
              alignLabelWithHint: true,
            ),
          ),
        );

    return AlertDialog(
      title: const Text('Referencia de dirección'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              field(_work, 'Obra y autor', 'Se7en · David Fincher'),
              field(
                _title,
                'Qué tomamos de ella',
                'El peso del entorno sobre el personaje',
              ),
              Text('Tipo de referencia', style: AppTypography.label(palette)),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  for (final kind in kDirectionReferenceKinds)
                    ChoiceChip(
                      label: Text(kind),
                      selected: _kind == kind,
                      onSelected: (on) =>
                          setState(() => _kind = on ? kind : ''),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              field(
                _why,
                'Por qué esta referencia',
                'Qué hace la obra y cómo lo consigue',
                maxLines: 6,
              ),
              field(
                _purpose,
                'Para qué en nuestra película',
                'Qué queremos contar o provocar con ella, y dónde',
                maxLines: 6,
              ),
              field(
                _scene,
                'Escena o momento (opcional)',
                'La llegada al piso, minuto 34',
              ),
              if (widget.images.isNotEmpty) ...[
                Text('Imagen (opcional)', style: AppTypography.label(palette)),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    for (final image in widget.images)
                      InkWell(
                        onTap: () => setState(
                          () => _imageId =
                              _imageId == image.id ? null : image.id,
                        ),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              width: 2,
                              color: _imageId == image.id
                                  ? palette.accent
                                  : Colors.transparent,
                            ),
                          ),
                          child:
                              _Thumbnail(path: image.imagePath, width: 96),
                        ),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        if (widget.canDelete)
          TextButton(
            onPressed: () =>
                Navigator.pop(context, const _ReferenceEdit.delete()),
            child: Text('Eliminar', style: TextStyle(color: palette.error)),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(onPressed: _save, child: const Text('Guardar')),
      ],
    );
  }
}
