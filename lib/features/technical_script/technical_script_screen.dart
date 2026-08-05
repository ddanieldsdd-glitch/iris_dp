import 'dart:io';

import 'dart:typed_data';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/app_database.dart';
import '../../core/database/database_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_layout.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/project_color_scheme.dart';
import '../../core/utils/scene_format.dart';
import '../../core/utils/shot_reference_import.dart';
import '../../core/utils/scene_characters.dart';
import '../../core/utils/user_error.dart';
import '../../core/widgets/app_button.dart';
import '../camera_plan/camera_plan_status_cell.dart';
import '../goodnotes/goodnotes_pdf_actions.dart';
import '../look_bible/look_bible_model.dart';
import '../shoot_documents/shoot_document_composer.dart';
import '../shoot_documents/shoot_document_import_actions.dart';
import '../shoot_documents/shoot_document_service.dart';
import '../pdf_export/technical_script_pdf.dart';
import 'scene_form_sheet.dart';
import '../../core/utils/shot_technical_options.dart';
import '../../core/widgets/inline_edit_field.dart';
import '../../core/widgets/app_snackbar.dart';
import '../../core/widgets/scene_meta_display.dart';

// Re-export para compatibilidad con imports existentes.
const kMovements = kShotMovements;
const kAngles = kShotAngles;

class TechnicalScriptScreen extends ConsumerWidget {
  final int projectId;
  const TechnicalScriptScreen({super.key, required this.projectId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(databaseProvider);
    final palette = context.palette;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: palette.surface,
        title:
            Text('Guion técnico', style: AppTypography.titleLarge(palette)),
        actions: [
          GoodNotesPdfActions(
            projectId: projectId,
            moduleType: GoodNotesModuleType.guionTecnico,
            filenameBase: 'guion_tecnico',
            buildPdfBytes: () async {
              final db = ref.read(databaseProvider);
              final project = await db.getProject(projectId);
              if (project == null) return Uint8List(0);
              final scenes = await db.watchScenesForProject(projectId).first;
              final shotsByScene = <int, List<Shot>>{};
              for (final scene in scenes) {
                shotsByScene[scene.id] =
                    await db.watchShotsForScene(scene.id).first;
              }
              return TechnicalScriptPdfExporter.buildBytes(
                project: project,
                scenes: scenes,
                shotsByScene: shotsByScene,
              );
            },
          ),
          IconButton(
            tooltip: 'Añadir al documento de rodaje',
            icon: Icon(Icons.description_outlined, color: palette.accent),
            onPressed: () => _addAllShotsToDocument(context, ref),
          ),
          IconButton(
            icon: Icon(Icons.picture_as_pdf_outlined, color: palette.accent),
            onPressed: () => _exportPdf(context, ref),
          ),
          IconButton(
            tooltip: 'Añadir escena',
            icon: Icon(Icons.add, color: palette.accent),
            onPressed: () => showSceneFormSheet(context, projectId: projectId),
          ),
        ],
      ),
      body: StreamBuilder<List<Scene>>(
        stream: db.watchScenesForProject(projectId),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final scenes = snap.data!;
          if (scenes.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Sin escenas. Importa el guion o añade una manualmente.',
                      style: AppTypography.bodyMedium(palette)),
                  const SizedBox(height: AppSpacing.lg),
                  AppButton(
                    label: 'Añadir escena',
                    icon: Icons.add,
                    onTap: () =>
                        showSceneFormSheet(context, projectId: projectId),
                  ),
                ],
              ),
            );
          }
          return StreamBuilder<List<LocationSite>>(
            stream: db.watchSitesForProject(projectId),
            builder: (context, siteSnap) {
              return StreamBuilder<List<LocationBasePlan>>(
                stream: db.watchLocationsForProject(projectId),
                builder: (context, locSnap) {
                  final colors = ProjectColorScheme.resolve(
                    sites: siteSnap.data ?? [],
                    sets: locSnap.data ?? [],
                    scenes: scenes,
                  );
                  return ListView.builder(
                    itemCount: scenes.length,
                    itemBuilder: (context, i) => _SceneSection(
                      scene: scenes[i],
                      colors: colors,
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _addAllShotsToDocument(BuildContext context, WidgetRef ref) async {
    final db = ref.read(databaseProvider);
    final scenes = await db.watchScenesForProject(projectId).first;
    if (scenes.isEmpty) {
      if (!context.mounted) return;
      AppSnackBar.show(context, 'No hay escenas.');
      return;
    }
    final doc = await ShootDocumentImportActions.pickDocument(
      context,
      db,
      projectId,
      title: 'Añadir guion técnico al documento',
    );
    if (doc == null || !context.mounted) return;

    final companions = await ShootDocumentComposer.compose(
      db: db,
      projectId: projectId,
      template: ShootDocumentTemplate.fullTechnical,
    );
    var order = await ShootDocumentService.nextSortOrder(db, doc.id);
    for (final c in companions) {
      await db.insertShootDocumentBlock(
        c.copyWith(documentId: Value(doc.id), sortOrder: Value(order++)),
      );
    }
    if (!context.mounted) return;
    AppSnackBar.show(context, 'Planos añadidos a «${doc.name}»');
  }

  Future<void> _exportPdf(BuildContext context, WidgetRef ref) async {
    final palette = context.palette;
    final db = ref.read(databaseProvider);
    try {
      final project = await db.getProject(projectId);
      if (project == null) return;

      final scenes = await db.watchScenesForProject(projectId).first;
      if (scenes.isEmpty) {
        if (!context.mounted) return;
        AppSnackBar.show(context, 'No hay escenas para exportar.');
        return;
      }

      final shotsByScene = <int, List<Shot>>{};
      for (final scene in scenes) {
        shotsByScene[scene.id] =
            await db.watchShotsForScene(scene.id).first;
      }

      final path = await TechnicalScriptPdfExporter.exportAndSave(
        project: project,
        scenes: scenes,
        shotsByScene: shotsByScene,
      );

      if (!context.mounted) return;
      if (path != null) {
        AppSnackBar.show(context, 'PDF guardado en $path');
      }
    } catch (e) {
      if (!context.mounted) return;
      AppSnackBar.show(context, userFriendlyError(e));
    }
  }
}

class _SceneSection extends ConsumerWidget {
  final Scene scene;
  final ProjectColorScheme colors;

  const _SceneSection({required this.scene, required this.colors});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(databaseProvider);
    final palette = context.palette;
    final accent = colors.sceneColor(scene);
    final locationName = locationFromCanonical(scene.locationCanonical);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.12),
            border: Border(
              left: BorderSide(color: accent, width: 5),
              bottom: BorderSide(color: palette.divider),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.xl,
            AppSpacing.md,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 14,
                height: 14,
                margin: const EdgeInsets.only(top: 4, right: AppSpacing.sm),
                decoration: BoxDecoration(
                  color: accent,
                  shape: BoxShape.circle,
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SceneMetaDisplay(
                      intExt: scene.intExt,
                      dayNight: scene.dayNight,
                      location: locationName,
                      style: AppTypography.titleMedium(palette).copyWith(
                        color: palette.textPrimary,
                        letterSpacing: 0.5,
                      ),
                      iconSize: 18,
                    ),
                    if (scene.description != null &&
                        scene.description!.trim().isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        scene.description!,
                        style: AppTypography.bodyMedium(palette).copyWith(
                          color: palette.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Añadir escena al documento de rodaje',
                icon: Icon(Icons.description_outlined,
                    color: palette.textSecondary, size: 18),
                onPressed: () => ShootDocumentImportActions.addSceneBlocks(
                  context: context,
                  db: ref.read(databaseProvider),
                  projectId: scene.projectId,
                  scene: scene,
                ),
              ),
              IconButton(
                tooltip: 'Editar escena',
                icon: Icon(Icons.edit_outlined,
                    color: palette.textSecondary, size: 18),
                onPressed: () => showSceneFormSheet(
                  context,
                  projectId: scene.projectId,
                  scene: scene,
                ),
              ),
            ],
          ),
        ),
        const _TableHeader(),
        StreamBuilder<List<Shot>>(
          stream: db.watchShotsForScene(scene.id),
          builder: (context, snap) {
            final shots = snap.data ?? [];
            return Column(
              children: [
                ...shots.map(
                  (s) => _ShotRow(
                    shot: s,
                    scene: scene,
                    sceneNumber: scene.number,
                  ),
                ),
                TextButton.icon(
                  onPressed: () async {
                    await db.insertShot(ShotsCompanion.insert(
                      sceneId: scene.id,
                      projectId: scene.projectId,
                      number: shots.length + 1,
                      sortOrder: Value(shots.length),
                    ));
                  },
                  icon: Icon(Icons.add, color: palette.accent, size: 16),
                  label: Text('Añadir plano',
                      style: AppTypography.label(palette)
                          .copyWith(color: palette.accent)),
                ),
                const SizedBox(height: AppSpacing.lg),
              ],
            );
          },
        ),
      ],
    );
  }
}

const kTechnicalScriptTableWidth = AppLayout.technicalScriptTableWidth;

/// Anchos de columnas — deben sumar [AppLayout.technicalScriptTableWidth] − md×2.
abstract final class _TechnicalScriptColumns {
  static const esc = 40.0;
  static const plano = 50.0;
  static const encuadre = 120.0;
  static const lens = 150.0;
  static const fStop = 30.0;
  static const personajes = 100.0;
  static const duracion = 60.0;
  static const action = 140.0;
  static const referencia = 90.0;
  static const planta = 56.0;
  static const apuntes = 100.0;
}

class _TableHeader extends StatelessWidget {
  const _TableHeader();

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SizedBox(
        width: AppLayout.technicalScriptTableWidth,
        child: Container(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md, vertical: AppSpacing.sm),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: palette.divider)),
          ),
          child: Row(children: [
            _HeaderCell('ESC', _TechnicalScriptColumns.esc, palette),
            _HeaderCell('PLANO', _TechnicalScriptColumns.plano, palette),
            _HeaderCell('Encuadre', _TechnicalScriptColumns.encuadre, palette),
            _HeaderCell('LENTE / MOV / ANG', _TechnicalScriptColumns.lens, palette),
            _HeaderCell('F', _TechnicalScriptColumns.fStop, palette),
            _HeaderCell('PERS.', _TechnicalScriptColumns.personajes, palette),
            _HeaderCell('DUR.', _TechnicalScriptColumns.duracion, palette),
            SizedBox(
              width: _TechnicalScriptColumns.action,
              child: Text('ACCIÓN', style: AppTypography.caption(palette)),
            ),
            _HeaderCell('REFERENCIA', _TechnicalScriptColumns.referencia, palette),
            _HeaderCell('PLANTA', _TechnicalScriptColumns.planta, palette),
            _HeaderCell('APUNTES', _TechnicalScriptColumns.apuntes, palette),
          ]),
        ),
      ),
    );
  }
}

class _HeaderCell extends StatelessWidget {
  final String text;
  final double width;
  final AppPalette palette;

  const _HeaderCell(this.text, this.width, this.palette);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Text(text, style: AppTypography.caption(palette)),
    );
  }
}

class _ShotRow extends ConsumerWidget {
  final Shot shot;
  final Scene scene;
  final int sceneNumber;

  const _ShotRow({
    required this.shot,
    required this.scene,
    required this.sceneNumber,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.read(databaseProvider);
    final palette = context.palette;

    final highlightColor = switch (shot.notesHighlight) {
      'green' => palette.highlightGreen,
      'yellow' => palette.highlightYellow,
      'red' => palette.highlightRed,
      _ => null,
    };

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SizedBox(
        width: AppLayout.technicalScriptTableWidth,
        child: Container(
          decoration: BoxDecoration(
            color: highlightColor,
            border:
                Border(bottom: BorderSide(color: palette.divider, width: 0.3)),
          ),
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md, vertical: AppSpacing.sm),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                  width: _TechnicalScriptColumns.esc,
                  child:
                      Text('$sceneNumber', style: AppTypography.mono(palette))),
              SizedBox(
                width: _TechnicalScriptColumns.plano,
                child: Text('${shot.number}',
                    style: AppTypography.mono(palette)
                        .copyWith(color: palette.accent)),
              ),
              SizedBox(
                width: _TechnicalScriptColumns.encuadre,
                child: InlineEditField(
                  value: shot.framing,
                  hint: 'PD, PMC...',
                  palette: palette,
                  minLines: 2,
                  onChanged: (v) =>
                      db.updateShot(shot.copyWith(framing: Value(v))),
                ),
              ),
              SizedBox(
                width: _TechnicalScriptColumns.lens,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    InlineEditField(
                      value: shot.lens,
                      hint: '50mm',
                      palette: palette,
                      onChanged: (v) =>
                          db.updateShot(shot.copyWith(lens: Value(v))),
                    ),
                    InlineDropdownField(
                      value: shot.movement,
                      options: kMovements,
                      hint: '—',
                      palette: palette,
                      onChanged: (v) =>
                          db.updateShot(shot.copyWith(movement: Value(v))),
                    ),
                    InlineDropdownField(
                      value: shot.angle,
                      options: kAngles,
                      hint: '—',
                      palette: palette,
                      onChanged: (v) =>
                          db.updateShot(shot.copyWith(angle: Value(v))),
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: _TechnicalScriptColumns.fStop,
                child: InlineEditField(
                  value: shot.fStop,
                  hint: 'T2.8',
                  palette: palette,
                  onChanged: (v) =>
                      db.updateShot(shot.copyWith(fStop: Value(v))),
                ),
              ),
              SizedBox(
                width: _TechnicalScriptColumns.personajes,
                child: InlineEditField(
                  value: decodeSceneCharacters(shot.charactersJson).join(', '),
                  hint: 'Ana, Luis…',
                  palette: palette,
                  minLines: 2,
                  onChanged: (v) => db.updateShot(
                    shot.copyWith(
                      charactersJson: Value(
                        encodeSceneCharacters(parseCharactersInput(v)),
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(
                width: _TechnicalScriptColumns.duracion,
                child: InlineEditField(
                  value: shot.durationSeconds?.toString(),
                  hint: 'seg',
                  palette: palette,
                  onChanged: (v) => db.updateShot(
                    shot.copyWith(durationSeconds: Value(int.tryParse(v.trim()))),
                  ),
                ),
              ),
              SizedBox(
                width: _TechnicalScriptColumns.action,
                child: InlineEditField(
                  value: shot.action,
                  hint: 'Descripción de la acción...',
                  minLines: 3,
                  palette: palette,
                  onChanged: (v) =>
                      db.updateShot(shot.copyWith(action: Value(v))),
                ),
              ),
              SizedBox(
                width: _TechnicalScriptColumns.referencia,
                child: _ReferenceCell(shot: shot),
              ),
              SizedBox(
                width: _TechnicalScriptColumns.planta,
                child: CameraPlanStatusCell(
                  shot: shot,
                  sceneNumber: sceneNumber,
                  scene: scene,
                ),
              ),
              SizedBox(
                width: _TechnicalScriptColumns.apuntes,
                height: 72,
                child: Row(
                  children: [
                    Expanded(child: _NotesCell(shot: shot, palette: palette)),
                    IconButton(
                      tooltip: 'Añadir plano al documento',
                      icon: Icon(Icons.add_link, color: palette.accent, size: 18),
                      onPressed: () => ShootDocumentImportActions.addShotBlock(
                        context: context,
                        db: db,
                        projectId: scene.projectId,
                        shot: shot,
                        scene: scene,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NotesCell extends ConsumerWidget {
  final Shot shot;
  final AppPalette palette;

  const _NotesCell({required this.shot, required this.palette});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.read(databaseProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: InlineEditField(
            value: shot.notes,
            hint: 'Apuntes...',
            minLines: 1,
            palette: palette,
            onChanged: (v) => db.updateShot(shot.copyWith(notes: Value(v))),
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _HighlightDot(
              color: palette.highlightGreen,
              selected: shot.notesHighlight == 'green',
              onTap: () => db.updateShot(
                shot.copyWith(notesHighlight: const Value('green')),
              ),
            ),
            const SizedBox(width: 6),
            _HighlightDot(
              color: palette.highlightYellow,
              selected: shot.notesHighlight == 'yellow',
              onTap: () => db.updateShot(
                shot.copyWith(notesHighlight: const Value('yellow')),
              ),
            ),
            const SizedBox(width: 6),
            _HighlightDot(
              color: palette.highlightRed,
              selected: shot.notesHighlight == 'red',
              onTap: () => db.updateShot(
                shot.copyWith(notesHighlight: const Value('red')),
              ),
            ),
            const SizedBox(width: 6),
            _HighlightDot(
              color: palette.divider,
              selected: shot.notesHighlight == null,
              onTap: () => db.updateShot(
                shot.copyWith(notesHighlight: const Value(null)),
              ),
              icon: Icons.close,
              size: 10,
            ),
          ],
        ),
      ],
    );
  }
}

class _HighlightDot extends StatelessWidget {
  final Color color;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;
  final double size;

  const _HighlightDot({
    required this.color,
    required this.selected,
    required this.onTap,
    this.icon,
    this.size = 14,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size + 6,
        height: size + 6,
        decoration: BoxDecoration(
          color: icon != null ? null : color.withValues(alpha: selected ? 1 : 0.35),
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? Colors.white : color,
            width: selected ? 2 : 1,
          ),
        ),
        child: icon != null
            ? Icon(icon, size: size, color: context.palette.textTertiary)
            : null,
      ),
    );
  }
}

class _ReferenceCell extends ConsumerWidget {
  final Shot shot;
  const _ReferenceCell({required this.shot});

  Future<void> _import(
    BuildContext context,
    WidgetRef ref, {
    required String source,
  }) async {
    final db = ref.read(databaseProvider);
    try {
      await pickAndImportShotReference(
        db: db,
        shot: shot,
        source: source,
        dialogTitle: 'Referencia · Plano ${shot.number}',
      );
    } catch (e) {
      if (context.mounted) {
        AppSnackBar.showError(context, userFriendlyError(e));
      }
    }
  }

  void _showImportOptions(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: palette.surfaceElevated,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Referencia · Plano ${shot.number}',
                style: AppTypography.titleMedium(palette),
              ),
              const SizedBox(height: AppSpacing.md),
              ListTile(
                leading: Icon(Icons.photo_camera_outlined, color: palette.accent),
                title: Text('Captura Artemis', style: AppTypography.bodyLarge(palette)),
                subtitle: Text(
                  'Exportada desde la app Artemis',
                  style: AppTypography.caption(palette),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _import(context, ref, source: ShotReferenceSource.artemisCapture);
                },
              ),
              ListTile(
                leading: Icon(Icons.add_photo_alternate_outlined,
                    color: palette.textSecondary),
                title: Text('Imagen manual', style: AppTypography.bodyLarge(palette)),
                onTap: () {
                  Navigator.pop(ctx);
                  _import(context, ref, source: ShotReferenceSource.manual);
                },
              ),
              ListTile(
                leading: Icon(Icons.view_in_ar_outlined, color: palette.accent),
                title: Text('Render Unreal', style: AppTypography.bodyLarge(palette)),
                subtitle: Text(
                  'Frame PNG del Movie Render Queue',
                  style: AppTypography.caption(palette),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _import(context, ref, source: ShotReferenceSource.unrealRender);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _removeImage(BuildContext context, WidgetRef ref) async {
    final palette = context.palette;
    final db = ref.read(databaseProvider);
    final path = shot.referenceImagePath;
    if (path == null) return;

    final refs = await db.watchReferencesForShot(shot.id).first;
    ShotReference? match;
    for (final r in refs) {
      if (r.imagePath == path) {
        match = r;
        break;
      }
    }

    try {
      if (match != null) {
        final current = await db.getShotById(shot.id) ?? shot;
        await deleteShotReferenceEntry(
          db: db,
          shot: current,
          reference: match,
        );
      } else {
        await db.updateShot(shot.copyWith(referenceImagePath: const Value(null)));
      }
    } catch (e) {
      if (!context.mounted) return;
      AppSnackBar.show(context, userFriendlyError(e));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final path = shot.referenceImagePath;
    final hasImage = path != null && File(path).existsSync();

    return GestureDetector(
      onTap: () => _showImportOptions(context, ref),
      onLongPress: hasImage ? () => _removeImage(context, ref) : null,
      child: Container(
        height: 72,
        decoration: BoxDecoration(
          color: palette.surfaceOverlay.withValues(alpha: 0.4),
          border: Border.all(color: palette.divider),
          borderRadius: BorderRadius.circular(6),
        ),
        clipBehavior: Clip.antiAlias,
        child: hasImage
            ? Stack(
                fit: StackFit.expand,
                children: [
                  Image.file(File(path), fit: BoxFit.cover),
                  Positioned(
                    right: 4,
                    bottom: 4,
                    child: Icon(Icons.photo_camera_outlined,
                        size: 14, color: Colors.white.withValues(alpha: 0.9)),
                  ),
                ],
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.photo_camera_outlined,
                      color: palette.textTertiary, size: 20),
                  const SizedBox(height: 2),
                  Text('Ref.',
                      style: AppTypography.caption(palette),
                      textAlign: TextAlign.center),
                ],
              ),
      ),
    );
  }
}
