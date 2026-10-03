import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/visual_bible/bible_reference.dart';
import '../../../shared/visual_bible/moodboard_association.dart';
import 'bible_point_images.dart';
import 'bible_point_panel.dart';

/// Textos de un mazo de referencias: cambian según la sección.
class BibleReferencesCopy {
  final String dialogTitle;
  final String emptyHint;
  final String workLabel;
  final String workHint;
  final String titleLabel;
  final String titleHint;
  final String whyLabel;
  final String whyHint;
  final String purposeLabel;
  final String purposeHint;
  final String sceneLabel;
  final String sceneHint;

  const BibleReferencesCopy({
    required this.dialogTitle,
    required this.emptyHint,
    this.workLabel = 'Obra y autor',
    this.workHint = 'Se7en · David Fincher',
    required this.titleLabel,
    required this.titleHint,
    required this.whyLabel,
    required this.whyHint,
    required this.purposeLabel,
    required this.purposeHint,
    this.sceneLabel = 'Escena o momento (opcional)',
    this.sceneHint = 'La llegada al piso, minuto 34',
  });

  static const direction = BibleReferencesCopy(
    dialogTitle: 'Referencia de dirección',
    emptyHint:
        'Añade las obras que guían la película y explica qué tomas de cada '
        'una: una emoción, una forma de contar, un tema, una puesta en escena.',
    titleLabel: 'Qué tomamos de ella',
    titleHint: 'El peso del entorno sobre el personaje',
    whyLabel: 'Por qué esta referencia',
    whyHint: 'Qué hace la obra y cómo lo consigue',
    purposeLabel: 'Para qué en la película',
    purposeHint: 'Qué queremos contar o provocar con ella, y dónde',
  );

  static const concept = BibleReferencesCopy(
    dialogTitle: 'Referencia visual',
    emptyHint:
        'Elige las imágenes que definen el look y razona cada una: qué te '
        'atrae de ella y qué vas a llevar a la película.',
    workLabel: 'Película y director de fotografía',
    workHint: 'Blade Runner 2049 · Roger Deakins',
    titleLabel: 'Qué nos atrae de esta imagen',
    titleHint: 'Siluetas contra una atmósfera densa',
    whyLabel: 'Por qué nos gusta',
    whyHint: 'Cómo está construida: luz, color, composición, textura',
    purposeLabel: 'Qué llevamos a la película',
    purposeHint: 'Dónde y cómo lo vamos a usar',
    sceneLabel: 'Plano o momento (opcional)',
    sceneHint: 'La entrada en Las Vegas',
  );
}

/// Mazo de referencias razonadas: tarjetas con imagen que abren su detalle.
class BibleReferencesDeck extends ConsumerWidget {
  final int projectId;
  final int bibleId;
  final String sectionId;
  final List<String> kinds;
  final BibleReferencesCopy copy;
  final List<BibleReference> references;
  final ValueChanged<List<BibleReference>> onChanged;
  final VoidCallback onAddImage;
  final VoidCallback onOpenMoodboard;

  const BibleReferencesDeck({
    super.key,
    required this.projectId,
    required this.bibleId,
    required this.sectionId,
    required this.kinds,
    required this.copy,
    required this.references,
    required this.onChanged,
    required this.onAddImage,
    required this.onOpenMoodboard,
  });

  Future<_ReferenceEdit?> _editDialog(
    BuildContext context, {
    required BibleReference initial,
    required int? imageId,
    required bool canDelete,
  }) =>
      showDialog<_ReferenceEdit>(
        context: context,
        builder: (_) => _ReferenceDialog(
          projectId: projectId,
          bibleId: bibleId,
          sectionId: sectionId,
          kinds: kinds,
          copy: copy,
          initial: initial,
          initialImageId: imageId,
          canDelete: canDelete,
        ),
      );

  void _apply(_ReferenceEdit? result, int? index) {
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

  Future<void> _add(BuildContext context, {int? imageId}) async {
    _apply(
      await _editDialog(
        context,
        initial: BibleReference(imageId: imageId),
        imageId: imageId,
        canDelete: false,
      ),
      null,
    );
  }

  Future<void> _open(
    BuildContext context,
    int index,
    MoodboardImage? image,
  ) async {
    final result = await Navigator.of(context).push<_ReferenceEdit>(
      MaterialPageRoute(
        builder: (_) => _ReferenceDetailScreen(
          reference: references[index],
          image: image,
          copy: copy,
          onEdit: (ctx) => _editDialog(
            ctx,
            initial: references[index],
            imageId: image?.id,
            canDelete: true,
          ),
        ),
      ),
    );
    _apply(result, index);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final db = ref.watch(databaseProvider);
    return StreamBuilder<List<MoodboardImage>>(
      stream: db.watchMoodboardImages(projectId),
      builder: (context, snap) {
        final all = snap.data ?? const <MoodboardImage>[];
        final byId = {for (final image in all) image.id: image};
        final sectionIds = [
          for (final image in all)
            if (MoodboardAssociation.visibleInSection(
              category: image.category,
              assignedSections: MoodboardAssociation.decodeSections(
                image.assignedSections,
              ),
              sectionId: sectionId,
            ))
              image.id,
        ];
        // Las fichas antiguas se emparejan por posición con las imágenes de
        // la sección; las nuevas pueden usar cualquier imagen del proyecto.
        final linked = [
          for (var i = 0; i < references.length; i++)
            references[i].legacyPairing
                ? (i < sectionIds.length ? sectionIds[i] : null)
                : (byId.containsKey(references[i].imageId)
                    ? references[i].imageId
                    : null),
        ];
        final unlinked = [
          for (final id in sectionIds)
            if (!linked.contains(id)) byId[id]!,
        ];

        return LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 900
                ? 3
                : constraints.maxWidth >= 560
                    ? 2
                    : 1;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (references.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.md),
                    child: Text(
                      copy.emptyHint,
                      style: AppTypography.bodyMedium(palette).copyWith(
                        color: palette.textSecondary,
                      ),
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
                                      whyLabel: copy.whyLabel,
                                      onTap: () => _open(
                                        context,
                                        row + c,
                                        byId[linked[row + c]],
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
                    'IMÁGENES SIN FICHA · TOCA UNA PARA RAZONARLA',
                    style: BiblePointPanel.labelStyle(palette),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: [
                      for (final image in unlinked)
                        InkWell(
                          onTap: () => _add(context, imageId: image.id),
                          borderRadius: BorderRadius.circular(6),
                          child: BibleImageThumb(
                            path: image.imagePath,
                            height: 72,
                          ),
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
                      () => _add(context),
                    ),
                    _action(
                      palette,
                      Icons.add_photo_alternate_outlined,
                      'Importar imagen',
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

class _KindChip extends StatelessWidget {
  final String kind;

  const _KindChip(this.kind);

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: palette.accent.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        kind.toUpperCase(),
        style: BiblePointPanel.labelStyle(palette).copyWith(
          fontSize: 10,
          color: Colors.white,
        ),
      ),
    );
  }
}

/// Tarjeta de referencia: la imagen manda y el título va sobre ella.
class _ReferenceCard extends StatelessWidget {
  final BibleReference reference;
  final MoodboardImage? image;
  final String whyLabel;
  final VoidCallback onTap;

  const _ReferenceCard({
    required this.reference,
    required this.image,
    required this.whyLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final file = image == null ? null : File(image!.imagePath);
    final hasImage = file != null && file.existsSync();
    final label = BiblePointPanel.labelStyle(palette).copyWith(fontSize: 10);
    final title = reference.title.isEmpty
        ? 'Referencia sin título'
        : reference.title;

    final heading = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (reference.kind.isNotEmpty) ...[
          _KindChip(reference.kind),
          const SizedBox(height: AppSpacing.sm),
        ],
        Text(
          title,
          style: AppTypography.titleMedium(palette).copyWith(
            color: hasImage ? Colors.white : palette.textPrimary,
            fontSize: 18,
            height: 1.2,
          ),
        ),
        if (reference.work.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            reference.work.toUpperCase(),
            style: label.copyWith(
              color: hasImage ? Colors.white70 : palette.textSecondary,
            ),
          ),
        ],
      ],
    );

    return Material(
      color: palette.surfaceOverlay.withValues(alpha: 0.45),
      borderRadius: BorderRadius.circular(BiblePointPanel.radius),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (hasImage)
              AspectRatio(
                aspectRatio: 16 / 9,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.file(file, fit: BoxFit.cover),
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.transparent, Colors.black87],
                          stops: [0.35, 1],
                        ),
                      ),
                    ),
                    Positioned(
                      left: AppSpacing.md,
                      right: AppSpacing.md,
                      bottom: AppSpacing.md,
                      child: heading,
                    ),
                  ],
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.md,
                  AppSpacing.md,
                  0,
                ),
                child: heading,
              ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(whyLabel.toUpperCase(), style: label),
                  const SizedBox(height: 4),
                  Text(
                    reference.why.isEmpty
                        ? 'Toca para razonar esta referencia…'
                        : reference.why,
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.bodyMedium(palette).copyWith(
                      height: 1.45,
                      color: reference.why.isEmpty
                          ? palette.textTertiary
                          : palette.textPrimary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text('ABRIR', style: label),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.arrow_forward,
                        size: 12,
                        color: palette.textSecondary,
                      ),
                    ],
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

/// Detalle de una referencia: la imagen grande y el razonamiento completo.
class _ReferenceDetailScreen extends StatefulWidget {
  final BibleReference reference;
  final MoodboardImage? image;
  final BibleReferencesCopy copy;
  final Future<_ReferenceEdit?> Function(BuildContext context) onEdit;

  const _ReferenceDetailScreen({
    required this.reference,
    required this.image,
    required this.copy,
    required this.onEdit,
  });

  @override
  State<_ReferenceDetailScreen> createState() => _ReferenceDetailScreenState();
}

class _ReferenceDetailScreenState extends State<_ReferenceDetailScreen> {
  Future<void> _edit() async {
    final result = await widget.onEdit(context);
    if (result != null && mounted) Navigator.pop(context, result);
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final reference = widget.reference;
    final file =
        widget.image == null ? null : File(widget.image!.imagePath);
    final label = BiblePointPanel.labelStyle(palette);

    Widget block(String heading, String text) => text.isEmpty
        ? const SizedBox.shrink()
        : Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.lg),
            child: BiblePointPanel(
              label: heading,
              child: Text(
                text,
                style: AppTypography.bodyLarge(palette).copyWith(height: 1.55),
              ),
            ),
          );

    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (reference.kind.isNotEmpty) ...[
          _KindChip(reference.kind),
          const SizedBox(height: AppSpacing.md),
        ],
        Text(
          reference.title.isEmpty ? 'Referencia sin título' : reference.title,
          style: AppTypography.displayMedium(palette).copyWith(fontSize: 32),
        ),
        if (reference.work.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(reference.work.toUpperCase(), style: label),
        ],
        const SizedBox(height: AppSpacing.lg),
        block(widget.copy.whyLabel, reference.why),
        block(widget.copy.purposeLabel, reference.purpose),
        block('Momento', reference.scene),
        if (reference.why.isEmpty && reference.purpose.isEmpty)
          Text(
            'Aún no has razonado esta referencia. Pulsa Editar.',
            style: AppTypography.bodyMedium(palette).copyWith(
              color: palette.textTertiary,
            ),
          ),
      ],
    );

    final picture = file != null && file.existsSync()
        ? ClipRRect(
            borderRadius: BorderRadius.circular(BiblePointPanel.radius),
            child: InkWell(
              onTap: () => showBibleImageViewer(context, path: file.path),
              child: Image.file(file, fit: BoxFit.contain),
            ),
          )
        : null;

    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        title: Text(widget.copy.dialogTitle),
        actions: [
          TextButton.icon(
            onPressed: _edit,
            icon: const Icon(Icons.edit_outlined, size: 16),
            label: const Text('Editar'),
          ),
          const SizedBox(width: AppSpacing.sm),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 900 && picture != null;
          return SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1200),
                child: wide
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 6, child: picture),
                          const SizedBox(width: AppSpacing.xl),
                          Expanded(flex: 5, child: text),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (picture != null) ...[
                            picture,
                            const SizedBox(height: AppSpacing.lg),
                          ],
                          text,
                        ],
                      ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ReferenceEdit {
  final BibleReference? reference;
  final bool delete;

  const _ReferenceEdit.save(this.reference) : delete = false;
  const _ReferenceEdit.delete()
      : reference = null,
        delete = true;
}

class _ReferenceDialog extends ConsumerStatefulWidget {
  final int projectId;
  final int bibleId;
  final String sectionId;
  final List<String> kinds;
  final BibleReferencesCopy copy;
  final BibleReference initial;
  final int? initialImageId;
  final bool canDelete;

  const _ReferenceDialog({
    required this.projectId,
    required this.bibleId,
    required this.sectionId,
    required this.kinds,
    required this.copy,
    required this.initial,
    required this.initialImageId,
    required this.canDelete,
  });

  @override
  ConsumerState<_ReferenceDialog> createState() => _ReferenceDialogState();
}

class _ReferenceDialogState extends ConsumerState<_ReferenceDialog> {
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
        BibleReference(
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

  Future<void> _pickImage() async {
    final picked = await showMoodboardImagePicker(
      context,
      projectId: widget.projectId,
      bibleId: widget.bibleId,
      sectionId: widget.sectionId,
      selected: [if (_imageId != null) _imageId!],
      single: true,
    );
    if (picked != null) {
      setState(() => _imageId = picked.isEmpty ? null : picked.first);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final copy = widget.copy;
    final db = ref.watch(databaseProvider);

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
            minLines: maxLines > 1 ? 3 : 1,
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
      title: Text(copy.dialogTitle),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              StreamBuilder<List<MoodboardImage>>(
                stream: db.watchMoodboardImages(widget.projectId),
                builder: (context, snap) {
                  final image = (snap.data ?? const <MoodboardImage>[])
                      .where((i) => i.id == _imageId)
                      .firstOrNull;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.md),
                    child: Row(
                      children: [
                        if (image != null) ...[
                          BibleImageThumb(path: image.imagePath, height: 72),
                          const SizedBox(width: AppSpacing.md),
                        ],
                        OutlinedButton.icon(
                          onPressed: _pickImage,
                          icon: const Icon(Icons.image_outlined, size: 16),
                          label: Text(
                            image == null ? 'Elegir imagen' : 'Cambiar imagen',
                          ),
                        ),
                        if (image != null)
                          TextButton(
                            onPressed: () => setState(() => _imageId = null),
                            child: const Text('Quitar'),
                          ),
                      ],
                    ),
                  );
                },
              ),
              field(_title, copy.titleLabel, copy.titleHint),
              field(_work, copy.workLabel, copy.workHint),
              Text('Tipo de referencia', style: AppTypography.label(palette)),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  for (final kind in widget.kinds)
                    ChoiceChip(
                      label: Text(kind),
                      selected: _kind == kind,
                      onSelected: (on) =>
                          setState(() => _kind = on ? kind : ''),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              field(_why, copy.whyLabel, copy.whyHint, maxLines: 8),
              field(
                _purpose,
                copy.purposeLabel,
                copy.purposeHint,
                maxLines: 8,
              ),
              field(_scene, copy.sceneLabel, copy.sceneHint),
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
