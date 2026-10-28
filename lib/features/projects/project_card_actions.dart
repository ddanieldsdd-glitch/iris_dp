import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:path/path.dart' as p;

import '../../core/database/app_database.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_layout.dart';
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
        width: AppLayout.dialogWidth(context, 340),
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

/// Colores de partida para las tarjetas; «Otro…» abre el selector completo.
const kProjectCardColors = <(String, Color)>[
  ('Ámbar', Color(0xFFFFB020)),
  ('Coral', Color(0xFFFF6B4A)),
  ('Rojo', Color(0xFFE5484D)),
  ('Magenta', Color(0xFFE93D82)),
  ('Violeta', Color(0xFF8E4EC6)),
  ('Índigo', Color(0xFF3E63DD)),
  ('Azul', Color(0xFF2997FF)),
  ('Cian', Color(0xFF05A2C2)),
  ('Verde', Color(0xFF30A46C)),
  ('Lima', Color(0xFF99D52A)),
  ('Arena', Color(0xFFD4B483)),
  ('Plata', Color(0xFFA0A0A8)),
];

Future<void> _writeProject(
  AppDatabase db,
  int projectId,
  ProjectsCompanion values,
) => (db.update(db.projects)..where((p) => p.id.equals(projectId))).write(
  values,
);

/// Elige el color de la tarjeta. Se aplica al tocarlo.
Future<void> chooseProjectCardColor(
  BuildContext context,
  AppDatabase db,
  Project project,
) => showDialog<void>(
  context: context,
  builder: (dialogContext) {
    final palette = dialogContext.palette;
    var current = project.cardColor;
    return StatefulBuilder(
      builder: (context, setState) {
        Future<void> pick(Color color) async {
          setState(() => current = color.toARGB32());
          await _writeProject(
            db,
            project.id,
            ProjectsCompanion(cardColor: Value(color.toARGB32())),
          );
        }

        return AlertDialog(
          backgroundColor: palette.surfaceElevated,
          title: const Text('Color de la tarjeta'),
          content: SizedBox(
            width: AppLayout.dialogWidth(context, 340),
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final (name, color) in kProjectCardColors)
                  Tooltip(
                    message: name,
                    child: InkWell(
                      onTap: () => pick(color),
                      customBorder: const CircleBorder(),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: current == color.toARGB32()
                                ? Colors.white
                                : Colors.transparent,
                            width: 3,
                          ),
                        ),
                      ),
                    ),
                  ),
                Tooltip(
                  message: 'Otro color',
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () async {
                      var chosen = Color(current ?? 0xFF2997FF);
                      await showDialog<void>(
                        context: context,
                        builder: (_) => AlertDialog(
                          backgroundColor: palette.surfaceElevated,
                          content: SingleChildScrollView(
                            child: ColorPicker(
                              pickerColor: chosen,
                              enableAlpha: false,
                              onColorChanged: (c) => chosen = c,
                            ),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Usar este color'),
                            ),
                          ],
                        ),
                      );
                      await pick(chosen);
                    },
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: palette.borderBright),
                      ),
                      child: Icon(Icons.colorize, color: palette.textSecondary),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () async {
                await _writeProject(
                  db,
                  project.id,
                  const ProjectsCompanion(cardColor: Value(null)),
                );
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text('Quitar color'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Listo'),
            ),
          ],
        );
      },
    );
  },
);

/// Cambia el tamaño de la tarjeta (S, M, L, XL).
Future<void> setProjectCardSize(
  AppDatabase db,
  Project project,
  ProjectCardSize size,
) => _writeProject(db, project.id, ProjectsCompanion(cardSize: Value(size.name)));

