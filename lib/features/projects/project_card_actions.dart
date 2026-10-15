import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../../core/database/app_database.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/media_storage.dart';
import '../../shared/visual_bible/bible_section_ids.dart';
import '../visual_bible/widgets/bible_point_images.dart';
import 'project_card_stats.dart';

/// Elige la imagen de la tarjeta con el selector del moodboard (que también
/// importa archivos y pega con ⌘V). Se copia a la carpeta de portada del
/// proyecto: borrar la imagen del moodboard no deja la tarjeta sin imagen.
Future<void> changeProjectCardImage(
  BuildContext context,
  AppDatabase db,
  Project project,
) async {
  final bible = await db.ensureVisualBibleForProject(project.id);
  if (!context.mounted) return;
  final picked = await showMoodboardImagePicker(
    context,
    projectId: project.id,
    bibleId: bible.id,
    sectionId: BibleSectionId.moodboard,
    selected: const [],
    single: true,
  );
  if (picked == null || picked.isEmpty) return;
  final image = await (db.select(
    db.moodboardImages,
  )..where((m) => m.id.equals(picked.first))).getSingleOrNull();
  if (image == null) return;
  final ext = p.extension(image.imagePath).isEmpty
      ? '.jpg'
      : p.extension(image.imagePath);
  final copied = await MediaStorage.copyFileIntoProject(
    projectId: project.id,
    sourcePath: image.imagePath,
    subfolder: 'cover',
    fileName: 'cover_${DateTime.now().millisecondsSinceEpoch}$ext',
  );
  if (copied == null) return;
  final current = await db.getProject(project.id);
  if (current == null) return;
  await db.updateProject(
    current.copyWith(coverImagePath: Value(copied), updatedAt: DateTime.now()),
  );
}

/// Elige qué datos enseña la tarjeta. Cada cambio se guarda al momento.
Future<void> chooseProjectCardData(
  BuildContext context,
  AppDatabase db,
  Project project,
) => showDialog<void>(
  context: context,
  builder: (_) => _CardDataDialog(db: db, project: project),
);

class _CardDataDialog extends StatefulWidget {
  final AppDatabase db;
  final Project project;

  const _CardDataDialog({required this.db, required this.project});

  @override
  State<_CardDataDialog> createState() => _CardDataDialogState();
}

class _CardDataDialogState extends State<_CardDataDialog> {
  late List<ProjectCardMetric> _chosen = ProjectCardMetric.of(
    widget.project.cardMetricsJson,
  );

  Future<void> _toggle(ProjectCardMetric metric) async {
    final next = _chosen.contains(metric)
        ? [
            for (final m in _chosen)
              if (m != metric) m,
          ]
        : [..._chosen, metric];
    if (next.isEmpty || next.length > ProjectCardMetric.maxShown) return;
    setState(() => _chosen = next);
    await (widget.db.update(
      widget.db.projects,
    )..where((p) => p.id.equals(widget.project.id))).write(
      ProjectsCompanion(
        cardMetricsJson: Value(ProjectCardMetric.encode(next)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final full = _chosen.length >= ProjectCardMetric.maxShown;
    return AlertDialog(
      backgroundColor: palette.surfaceElevated,
      title: const Text('Datos de la tarjeta'),
      content: SizedBox(
        width: 340,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Hasta ${ProjectCardMetric.maxShown}. Los de avance salen con '
              'barra y cuentan para el anillo.',
              style: AppTypography.caption(palette),
            ),
            const SizedBox(height: 8),
            for (final metric in ProjectCardMetric.values)
              CheckboxListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                value: _chosen.contains(metric),
                onChanged: !_chosen.contains(metric) && full
                    ? null
                    : (_) => _toggle(metric),
                secondary: Icon(metric.icon, size: 18),
                title: Text(metric.label),
                subtitle: metric.isProgress
                    ? Text('Avance', style: AppTypography.caption(palette))
                    : null,
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Listo'),
        ),
      ],
    );
  }
}
