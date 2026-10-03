import 'dart:async';
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

  static const technical = BibleReferencesCopy(
    dialogTitle: 'Referencia técnica',
    emptyHint:
        'Reúne los planos cuyo resultado técnico quieres reproducir y '
        'anota cómo se hicieron y qué necesitas para lograrlo.',
    workLabel: 'Película y equipo',
    workHint: '1917 · Roger Deakins',
    titleLabel: 'Qué queremos reproducir',
    titleHint: 'Plano secuencia con cambio de luz día a noche',
    whyLabel: 'Cómo se hizo',
    whyHint: 'Cámara, óptica, luz, soportes, ajustes',
    purposeLabel: 'Qué necesitamos',
    purposeHint: 'Equipo, pruebas previas y riesgos',
    sceneLabel: 'Plano o momento (opcional)',
    sceneHint: 'La carrera final',
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

/// Mazo de referencias razonadas: tarjetas con imagen que abren su página
/// de edición.
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

  /// Abre la página de edición de la ficha [index] de [list]. Cada cambio se
  /// guarda al momento; al volver, una ficha que quedó vacía se descarta.
  Future<void> _open(
    BuildContext context,
    List<BibleReference> list,
    int index,
    List<int> imageIds,
  ) async {
    var current = [...list];
    current[index] = current[index].copyWith(imageIds: imageIds);
    var deleted = false;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => BibleReferenceEditorScreen(
          projectId: projectId,
          bibleId: bibleId,
          sectionId: sectionId,
          kinds: kinds,
          copy: copy,
          initial: current[index],
          onChanged: (updated) {
            current = [...current]..[index] = updated;
            onChanged(current);
          },
          onDelete: () {
            deleted = true;
            onChanged([...current]..removeAt(index));
          },
        ),
      ),
    );
    final edited = current[index];
    if (!deleted && edited.isEmpty && edited.imageIds.isEmpty) {
      onChanged([...current]..removeAt(index));
    }
  }

  Future<void> _add(BuildContext context, {int? imageId}) {
    final list = [
      ...references,
      BibleReference(imageIds: [if (imageId != null) imageId]),
    ];
    return _open(context, list, list.length - 1, [
      if (imageId != null) imageId,
    ]);
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
        final imagesOf = [
          for (var i = 0; i < references.length; i++)
            references[i].legacyPairing
                ? [if (i < sectionIds.length) sectionIds[i]]
                : [
                    for (final id in references[i].imageIds)
                      if (byId.containsKey(id)) id,
                  ],
        ];
        final used = {for (final ids in imagesOf) ...ids};
        final unlinked = [
          for (final id in sectionIds)
            if (!used.contains(id)) byId[id]!,
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
                      style: AppTypography.bodyMedium(
                        palette,
                      ).copyWith(color: palette.textSecondary),
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
                                      cover: imagesOf[row + c].isEmpty
                                          ? null
                                          : byId[imagesOf[row + c].first],
                                      imageCount: imagesOf[row + c].length,
                                      whyLabel: copy.whyLabel,
                                      onTap: () => _open(
                                        context,
                                        references,
                                        row + c,
                                        imagesOf[row + c],
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
  ) => TextButton.icon(
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
        style: BiblePointPanel.labelStyle(
          palette,
        ).copyWith(fontSize: 10, color: Colors.white),
      ),
    );
  }
}

/// Tarjeta de referencia: la imagen manda y el título va sobre ella.
class _ReferenceCard extends StatelessWidget {
  final BibleReference reference;
  final MoodboardImage? cover;
  final int imageCount;
  final String whyLabel;
  final VoidCallback onTap;

  const _ReferenceCard({
    required this.reference,
    required this.cover,
    required this.imageCount,
    required this.whyLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final file = cover == null ? null : File(cover!.imagePath);
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
                    if (imageCount > 1)
                      Positioned(
                        top: AppSpacing.sm,
                        right: AppSpacing.sm,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.photo_library_outlined,
                                size: 12,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '$imageCount',
                                style: label.copyWith(color: Colors.white),
                              ),
                            ],
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

/// Página de una referencia: se lee y se edita en el mismo sitio.
///
/// Carga las imágenes del moodboard y delega en [BibleReferenceEditor].
class BibleReferenceEditorScreen extends ConsumerWidget {
  final int projectId;
  final int bibleId;
  final String sectionId;
  final List<String> kinds;
  final BibleReferencesCopy copy;
  final BibleReference initial;
  final ValueChanged<BibleReference> onChanged;
  final VoidCallback onDelete;

  const BibleReferenceEditorScreen({
    super.key,
    required this.projectId,
    required this.bibleId,
    required this.sectionId,
    required this.kinds,
    required this.copy,
    required this.initial,
    required this.onChanged,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(databaseProvider);
    return StreamBuilder<List<MoodboardImage>>(
      stream: db.watchMoodboardImages(projectId),
      builder: (context, snap) => BibleReferenceEditor(
        kinds: kinds,
        copy: copy,
        initial: initial,
        imagePaths: {
          for (final image in snap.data ?? const <MoodboardImage>[])
            image.id: image.imagePath,
        },
        onChanged: onChanged,
        onDelete: onDelete,
        onPickImages: (selected) => showMoodboardImagePicker(
          context,
          projectId: projectId,
          bibleId: bibleId,
          sectionId: sectionId,
          selected: selected,
        ),
      ),
    );
  }
}

/// Editor de una referencia. No depende de la base de datos: recibe las
/// rutas de las imágenes y avisa de cada cambio con [onChanged].
class BibleReferenceEditor extends StatefulWidget {
  final List<String> kinds;
  final BibleReferencesCopy copy;
  final BibleReference initial;

  /// Ruta en disco de cada imagen del moodboard, por id.
  final Map<int, String> imagePaths;
  final ValueChanged<BibleReference> onChanged;
  final VoidCallback onDelete;

  /// Abre el selector de imágenes con las ya elegidas.
  final Future<List<int>?> Function(List<int> selected) onPickImages;

  const BibleReferenceEditor({
    super.key,
    required this.kinds,
    required this.copy,
    required this.initial,
    required this.imagePaths,
    required this.onChanged,
    required this.onDelete,
    required this.onPickImages,
  });

  @override
  State<BibleReferenceEditor> createState() => _BibleReferenceEditorState();
}

class _BibleReferenceEditorState extends State<BibleReferenceEditor> {
  static const _saveDelay = Duration(milliseconds: 500);

  late final _title = TextEditingController(text: widget.initial.title);
  late final _work = TextEditingController(text: widget.initial.work);
  late final _why = TextEditingController(text: widget.initial.why);
  late final _purpose = TextEditingController(text: widget.initial.purpose);
  late final _scene = TextEditingController(text: widget.initial.scene);
  late String _kind = widget.initial.kind;
  late List<int> _imageIds = [...widget.initial.imageIds];
  Timer? _debounce;
  bool _dirty = false;
  bool _deleted = false;

  BibleReference get _current => widget.initial.copyWith(
    title: _title.text.trim(),
    work: _work.text.trim(),
    kind: _kind,
    why: _why.text.trim(),
    purpose: _purpose.text.trim(),
    scene: _scene.text.trim(),
    imageIds: _imageIds,
  );

  @override
  void dispose() {
    _debounce?.cancel();
    if (_dirty && !_deleted) widget.onChanged(_current);
    for (final c in [_title, _work, _why, _purpose, _scene]) {
      c.dispose();
    }
    super.dispose();
  }

  /// Guarda tras una pausa al escribir.
  void _touch() {
    setState(() => _dirty = true);
    _debounce?.cancel();
    _debounce = Timer(_saveDelay, _flush);
  }

  /// Guarda ya (imágenes, tipo).
  void _flush() {
    _debounce?.cancel();
    widget.onChanged(_current);
    if (mounted) setState(() => _dirty = false);
  }

  Future<void> _pickImages() async {
    final picked = await widget.onPickImages(_imageIds);
    if (picked == null || !mounted) return;
    setState(() => _imageIds = picked);
    _flush();
  }

  void _setCover(int id) {
    setState(() => _imageIds = [id, ..._imageIds.where((i) => i != id)]);
    _flush();
  }

  void _removeImage(int id) {
    setState(() => _imageIds = _imageIds.where((i) => i != id).toList());
    _flush();
  }

  Future<void> _confirmDelete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar referencia'),
        content: const Text(
          'Se borra la ficha. Las imágenes siguen en el moodboard.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    _deleted = true;
    _debounce?.cancel();
    widget.onDelete();
    Navigator.pop(context);
  }

  InputDecoration _bare(AppPalette palette, String hint, TextStyle style) =>
      InputDecoration(
        hintText: hint,
        hintStyle: style.copyWith(color: palette.textTertiary),
        isDense: true,
        filled: false,
        contentPadding: EdgeInsets.zero,
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
      );

  Widget _section(
    AppPalette palette,
    String label,
    TextEditingController controller,
    String hint, {
    IconData? icon,
  }) {
    final style = AppTypography.bodyLarge(palette).copyWith(height: 1.55);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: BiblePointPanel(
        label: label,
        icon: icon,
        child: TextField(
          controller: controller,
          minLines: 3,
          maxLines: null,
          style: style,
          textCapitalization: TextCapitalization.sentences,
          decoration: _bare(palette, hint, style),
          onChanged: (_) => _touch(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final copy = widget.copy;
    final label = BiblePointPanel.labelStyle(palette);
    final existing = [
      for (final id in _imageIds)
        if (widget.imagePaths[id] != null) id,
    ];
    final cover = existing.isEmpty ? null : widget.imagePaths[existing.first];
    final titleStyle = AppTypography.displayMedium(
      palette,
    ).copyWith(fontSize: 30, height: 1.2);
    final workStyle = AppTypography.mono(palette).copyWith(fontSize: 13);

    final gallery = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (cover != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(BiblePointPanel.radius),
            child: InkWell(
              onTap: () => showBibleImageViewer(context, path: cover),
              child: Image.file(File(cover), fit: BoxFit.contain),
            ),
          )
        else
          InkWell(
            onTap: _pickImages,
            borderRadius: BorderRadius.circular(BiblePointPanel.radius),
            child: Container(
              height: 220,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(BiblePointPanel.radius),
                border: Border.all(color: palette.border),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.add_photo_alternate_outlined,
                    size: 32,
                    color: palette.textSecondary,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text('AÑADIR IMÁGENES', style: label),
                  const SizedBox(height: 4),
                  Text(
                    'Opcional: una referencia puede ser solo texto.',
                    style: AppTypography.caption(palette),
                  ),
                ],
              ),
            ),
          ),
        if (existing.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final id in existing)
                _EditorThumb(
                  path: widget.imagePaths[id]!,
                  isCover: id == existing.first,
                  onTap: () => _setCover(id),
                  onRemove: () => _removeImage(id),
                ),
              InkWell(
                onTap: _pickImages,
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  width: 72 * 16 / 9,
                  height: 72,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: palette.border),
                  ),
                  child: Icon(Icons.add, color: palette.textSecondary),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Toca una imagen para ponerla de portada.',
            style: AppTypography.caption(palette),
          ),
        ],
      ],
    );

    final fields = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _title,
          minLines: 1,
          maxLines: null,
          style: titleStyle,
          textCapitalization: TextCapitalization.sentences,
          decoration: _bare(palette, copy.titleLabel, titleStyle),
          onChanged: (_) => _touch(),
        ),
        const SizedBox(height: AppSpacing.sm),
        TextField(
          controller: _work,
          style: workStyle,
          decoration: _bare(palette, copy.workHint, workStyle),
          onChanged: (_) => _touch(),
        ),
        const SizedBox(height: AppSpacing.md),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (final kind in widget.kinds)
              ChoiceChip(
                label: Text(kind),
                selected: _kind == kind,
                onSelected: (on) {
                  setState(() => _kind = on ? kind : '');
                  _flush();
                },
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        _section(
          palette,
          copy.whyLabel,
          _why,
          copy.whyHint,
          icon: Icons.psychology_outlined,
        ),
        _section(
          palette,
          copy.purposeLabel,
          _purpose,
          copy.purposeHint,
          icon: Icons.flag_outlined,
        ),
        BiblePointPanel(
          label: copy.sceneLabel,
          icon: Icons.schedule_outlined,
          child: TextField(
            controller: _scene,
            style: AppTypography.bodyLarge(palette),
            decoration: _bare(
              palette,
              copy.sceneHint,
              AppTypography.bodyLarge(palette),
            ),
            onChanged: (_) => _touch(),
          ),
        ),
      ],
    );

    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        title: Text(copy.dialogTitle),
        actions: [
          Center(
            child: Text(
              _dirty ? 'GUARDANDO…' : 'GUARDADO',
              style: label.copyWith(
                color: _dirty ? palette.warning : palette.textTertiary,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          IconButton(
            tooltip: 'Eliminar referencia',
            onPressed: _confirmDelete,
            icon: const Icon(Icons.delete_outline),
          ),
          const SizedBox(width: AppSpacing.sm),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 900;
          return SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1280),
                child: wide
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 6, child: gallery),
                          const SizedBox(width: AppSpacing.xl),
                          Expanded(flex: 5, child: fields),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          gallery,
                          const SizedBox(height: AppSpacing.lg),
                          fields,
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

/// Miniatura de la galería del editor: toca para portada, × para quitar.
class _EditorThumb extends StatelessWidget {
  final String path;
  final bool isCover;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  const _EditorThumb({
    required this.path,
    required this.isCover,
    required this.onTap,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Stack(
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                width: 2,
                color: isCover ? palette.accent : Colors.transparent,
              ),
            ),
            child: BibleImageThumb(path: path, height: 72),
          ),
        ),
        if (isCover)
          Positioned(
            left: 6,
            bottom: 6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: palette.accent,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'PORTADA',
                style: TextStyle(fontSize: 8, color: Colors.white),
              ),
            ),
          ),
        Positioned(
          top: 0,
          right: 0,
          child: InkWell(
            onTap: onRemove,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: const BoxDecoration(
                color: Colors.black54,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close, size: 12, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }
}
