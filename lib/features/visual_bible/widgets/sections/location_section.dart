import 'dart:io';

import 'package:path/path.dart' as p;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/database/database_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/clipboard_image_reader.dart';
import '../../../../core/utils/media_storage.dart';
import '../../../../core/widgets/app_card.dart';
import '../bible_section_shared_widgets.dart';
import '../../services/color_extraction_service.dart';
import '../../bible_paste_helpers.dart';
import '../../moodboard_helpers.dart';
import '../../visual_bible_model.dart';
import '../bible_form_widgets.dart';
import '../bible_navigation_scope.dart';
import '../bible_paste_zone.dart';
import '../moodboard_strip.dart';

class LocationSection extends ConsumerWidget {
  final int projectId;
  final int bibleId;

  const LocationSection({
    super.key,
    required this.projectId,
    required this.bibleId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final db = ref.watch(databaseProvider);

    return StreamBuilder<List<LocationSite>>(
      stream: db.watchSitesForProject(projectId),
      builder: (context, siteSnap) {
        final sites = siteSnap.data ?? [];

        return StreamBuilder<List<LocationBasePlan>>(
          stream: db.watchLocationsForProject(projectId),
          builder: (context, locSnap) {
            final allSets = locSnap.data ?? [];
            if (sites.isEmpty && allSets.isEmpty) {
              return Center(
                child: Text(
                  'Las localizaciones se generan al importar el guion.',
                  style: AppTypography.bodyMedium(palette)
                      .copyWith(color: palette.textTertiary),
                ),
              );
            }

            return StreamBuilder<List<VisualBibleLocationRef>>(
              stream: db.watchLocationRefsForBible(bibleId),
              builder: (context, refSnap) {
                final refsByPlanId = {
                  for (final r in refSnap.data ?? [])
                    if (r.locationBasePlanId != null)
                      r.locationBasePlanId!: r,
                };
                final refsByName = {
                  for (final r in refSnap.data ?? []) r.locationName: r,
                };

                final orphanSets =
                    allSets.where((s) => s.siteId == null).toList();

                return ListView(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  children: [
                    // ── Cabecera de sección ──────────────────────────────
                    const BibleSectionHeader(
                      number: '11',
                      title: 'Localización',
                    ),

                    // ── Compás solar ─────────────────────────────────────
                    AppCard(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.wb_sunny_outlined,
                                  size: 16,
                                  color: palette.warning),
                              const SizedBox(width: 6),
                              Text(
                                'COMPÁS SOLAR',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: palette.warning,
                                  letterSpacing: 1.1,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.md),
                          const Row(
                            children: [
                              Expanded(
                                child: BibleTechCard(
                                  label: 'Azimuth amanecer',
                                  value: '— °',
                                ),
                              ),
                              SizedBox(width: 8),
                              Expanded(
                                child: BibleTechCard(
                                  label: 'Azimuth atardecer',
                                  value: '— °',
                                ),
                              ),
                              SizedBox(width: 8),
                              Expanded(
                                child: BibleTechCard(
                                  label: 'Ventana de luz útil',
                                  value: '— h',
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          // Mini-arco solar decorativo
                          Container(
                            height: 56,
                            decoration: BoxDecoration(
                              color: palette.surfaceElevated,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                Text('Golden Hour',
                                    style: TextStyle(
                                        fontSize: 10,
                                        color: palette.warning)),
                                Icon(Icons.sunny,
                                    color: palette.warning
                                        .withValues(alpha: 0.4),
                                    size: 20),
                                Icon(Icons.wb_sunny_outlined,
                                    color: palette.warning, size: 28),
                                Icon(Icons.wb_sunny_outlined,
                                    color:
                                        palette.warning.withValues(alpha: 0.4),
                                    size: 20),
                                Text('Blue Hour',
                                    style: TextStyle(
                                        fontSize: 10,
                                        color: palette.accent)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),

                    // ── Gaffer Intel ─────────────────────────────────────
                    const AppCard(
                      padding: EdgeInsets.all(AppSpacing.lg),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          BibleGafferDirectiveBox(
                            title: 'Gaffer Intel',
                            text:
                                'Power Availability / Access & Staging / Permits & Restrictions — definir al hacer el tech scout.',
                          ),
                          SizedBox(height: AppSpacing.md),
                          Row(
                            children: [
                              Expanded(
                                child: BibleTechCard(
                                  label: 'Power Supply',
                                  value: '—',
                                  mono: false,
                                ),
                              ),
                              SizedBox(width: 8),
                              Expanded(
                                child: BibleTechCard(
                                  label: 'Crew Parking',
                                  value: '—',
                                  mono: false,
                                ),
                              ),
                              SizedBox(width: 8),
                              Expanded(
                                child: BibleTechCard(
                                  label: 'Sound Issues',
                                  value: '—',
                                  mono: false,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),

                    // ── Localizaciones ────────────────────────────────────
                    for (final site in sites) ...[
                      _SiteFolderHeader(
                        siteName: site.name,
                        onOpenLocations: () =>
                            BibleNavigationScope.openLocationSet(
                          context,
                          siteId: site.id,
                        ),
                      ),
                      ...allSets
                          .where((set) => set.siteId == site.id)
                          .map((loc) {
                        final ref = refsByPlanId[loc.id] ??
                            refsByName[loc.locationName];
                        final model = ref != null
                            ? LocationRefModel.fromRow(ref)
                            : LocationRefModel(
                                id: 0,
                                bibleId: bibleId,
                                locationName: loc.locationName,
                                locationSiteId: site.id,
                                locationBasePlanId: loc.id,
                              );
                        if (model.locationBasePlanId == null) {
                          model.locationBasePlanId = loc.id;
                          model.locationSiteId = site.id;
                        }
                        return Padding(
                          padding: const EdgeInsets.only(
                            left: AppSpacing.lg,
                            bottom: AppSpacing.lg,
                          ),
                          child: _LocationCard(
                            locColor: Color(
                              int.parse(loc.color.replaceFirst('#', '0xFF')),
                            ),
                            model: model,
                            projectId: projectId,
                            siteId: site.id,
                            setId: loc.id,
                            onSave: (m) => db.upsertLocationRef(m.toCompanion()),
                          ),
                        );
                      }),
                      const SizedBox(height: AppSpacing.md),
                    ],
                    if (orphanSets.isNotEmpty) ...[
                      _SiteFolderHeader(
                        siteName: 'Sin localización contenedora',
                        onOpenLocations: () =>
                            BibleNavigationScope.openLocationSet(context),
                      ),
                      ...orphanSets.map((loc) {
                        final ref = refsByPlanId[loc.id] ??
                            refsByName[loc.locationName];
                        final model = ref != null
                            ? LocationRefModel.fromRow(ref)
                            : LocationRefModel(
                                id: 0,
                                bibleId: bibleId,
                                locationName: loc.locationName,
                                locationBasePlanId: loc.id,
                              );
                        return Padding(
                          padding: const EdgeInsets.only(
                            left: AppSpacing.lg,
                            bottom: AppSpacing.lg,
                          ),
                          child: _LocationCard(
                            locColor: Color(
                              int.parse(loc.color.replaceFirst('#', '0xFF')),
                            ),
                            model: model,
                            projectId: projectId,
                            setId: loc.id,
                            onSave: (m) => db.upsertLocationRef(m.toCompanion()),
                          ),
                        );
                      }),
                    ],
                  ],
                );
              },
            );
          },
        );
      },
    );
  }
}

class _SiteFolderHeader extends StatelessWidget {
  final String siteName;
  final VoidCallback onOpenLocations;

  const _SiteFolderHeader({
    required this.siteName,
    required this.onOpenLocations,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          Icon(Icons.folder_outlined, size: 20, color: palette.accent),
          const SizedBox(width: 8),
          Expanded(
            child: Text(siteName, style: AppTypography.titleMedium(palette)),
          ),
          TextButton.icon(
            onPressed: onOpenLocations,
            icon: const Icon(Icons.open_in_new, size: 16),
            label: const Text('Localizaciones'),
          ),
        ],
      ),
    );
  }
}

class _LocationCard extends ConsumerStatefulWidget {
  final Color locColor;
  final LocationRefModel model;
  final int projectId;
  final int? siteId;
  final int? setId;
  final Future<void> Function(LocationRefModel) onSave;

  const _LocationCard({
    required this.locColor,
    required this.model,
    required this.projectId,
    this.siteId,
    this.setId,
    required this.onSave,
  });

  @override
  ConsumerState<_LocationCard> createState() => _LocationCardState();
}

class _LocationCardState extends ConsumerState<_LocationCard> {
  late LocationRefModel _model;

  @override
  void initState() {
    super.initState();
    _model = widget.model;
  }

  Future<void> _addPhoto() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: true,
    );
    if (result == null) return;

    for (final file in result.files) {
      final path = file.path;
      if (path == null) continue;
      final stored = await MediaStorage.copyFileIntoProject(
        projectId: widget.projectId,
        sourcePath: path,
        subfolder: 'visual_bible/locations',
        fileName: 'loc_${DateTime.now().millisecondsSinceEpoch}${p.extension(path).isEmpty ? '.jpg' : p.extension(path)}',
      );
      if (stored == null) continue;
      _model.referenceImages.add(stored);

      final extraction = await ColorExtractionService.extractFromFile(stored);
      if (extraction.estimatedKelvin != null &&
          _model.estimatedColorTempKelvin == null) {
        _model.estimatedColorTempKelvin = extraction.estimatedKelvin;
      }
    }
    setState(() {});
    await widget.onSave(_model);
  }

  Future<void> _pastePhotoFromPayload(ClipboardImagePayload payload) async {
    final stored = await BiblePasteHelpers.savePayloadToProject(
      projectId: widget.projectId,
      subfolder: 'visual_bible/locations',
      payload: payload,
      prefix: 'loc',
    );
    if (stored == null) return;
    _model.referenceImages.add(stored);

    final extraction = await ColorExtractionService.extractFromFile(stored);
    if (extraction.estimatedKelvin != null &&
        _model.estimatedColorTempKelvin == null) {
      _model.estimatedColorTempKelvin = extraction.estimatedKelvin;
    }
    setState(() {});
    await widget.onSave(_model);
  }

  Future<void> _pasteMoodboardRef(ClipboardImagePayload payload) async {
    final db = ref.read(databaseProvider);
    await MoodboardHelpers.addImageFromBytesAssigned(
      db: db,
      projectId: widget.projectId,
      bytes: payload.bytes,
      extension: payload.extension,
      assignedSections: [BibleSectionId.location],
      linkedLocationName: _model.locationName,
      linkedLocationBasePlanId: widget.setId ?? _model.locationBasePlanId,
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.folder_special_outlined,
                  size: 18, color: palette.textSecondary),
              const SizedBox(width: 8),
              Container(
                width: 16,
                height: 16,
                decoration:
                    BoxDecoration(color: widget.locColor, shape: BoxShape.circle),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _model.locationName,
                  style: AppTypography.titleMedium(palette),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (_model.estimatedColorTempKelvin != null) ...[
                const Spacer(),
                Text(
                  '~${_model.estimatedColorTempKelvin}K',
                  style: AppTypography.caption(palette),
                ),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Tratamiento visual del espacio (no scouting). '
            'Las fotos de recce van en la pantalla de Localizaciones.',
            style: AppTypography.caption(palette)
                .copyWith(color: palette.textSecondary),
          ),
          const SizedBox(height: AppSpacing.md),
          BibleTextField(
            label: 'Puesta en escena',
            hint: 'Cómo tratar el espacio, bloqueo, relación con la cámara…',
            maxLines: 3,
            initialValue: _model.stagingNote,
            onChanged: (v) => _model.stagingNote = v,
          ),
          const SizedBox(height: AppSpacing.sm),
          BibleTextField(
            label: 'Tratamiento de luz',
            hint: 'Luz natural filtrada, prácticas, contraste…',
            maxLines: 3,
            initialValue: _model.lightingNote,
            onChanged: (v) => _model.lightingNote = v,
          ),
          const SizedBox(height: AppSpacing.sm),
          BibleTextField(
            label: 'Paleta de esta localización',
            hint: 'Ocres, terracotas…',
            maxLines: 2,
            initialValue: _model.colorNote,
            onChanged: (v) => _model.colorNote = v,
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: BibleTextField(
                  label: 'Orientación solar',
                  hint: 'Ventana sur, luz matutina…',
                  initialValue: _model.solarOrientation,
                  onChanged: (v) => _model.solarOrientation = v,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: BibleTextField(
                  label: 'Horas de luz disponible',
                  hint: '10:00–14:00',
                  initialValue: _model.availableLightHours,
                  onChanged: (v) => _model.availableLightHours = v,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          BibleTextField(
            label: 'Prácticas existentes en el espacio',
            hint: 'Lámparas, ventanas…',
            maxLines: 2,
            initialValue: _model.existingPracticals,
            onChanged: (v) => _model.existingPracticals = v,
          ),
          const SizedBox(height: AppSpacing.md),
          BibleTargetZone(
            hint:
                'Clic aquí → ⌘V para pegar foto propia de ${_model.locationName}',
            minHeight: _model.referenceImages.isEmpty ? 72 : 88,
            onPaste: _pastePhotoFromPayload,
            child: _model.referenceImages.isEmpty
                ? null
                : Padding(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    child: SizedBox(
                      height: 80,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _model.referenceImages.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(width: 8),
                        itemBuilder: (_, i) {
                          final file = File(_model.referenceImages[i]);
                          return ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: file.existsSync()
                                ? Image.file(
                                    file,
                                    width: 100,
                                    height: 80,
                                    fit: BoxFit.cover,
                                  )
                                : const SizedBox(width: 100, height: 80),
                          );
                        },
                      ),
                    ),
                  ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Referencias del moodboard · ${_model.locationName}',
            style: AppTypography.label(palette),
          ),
          const SizedBox(height: AppSpacing.sm),
          BibleTargetZone(
            hint:
                'Clic aquí → ⌘V para pegar ref del moodboard en este set',
            minHeight: 88,
            onPaste: _pasteMoodboardRef,
            onMoodboardDropped: (drag) => MoodboardHelpers.linkMoodboardToSection(
              db: ref.read(databaseProvider),
              projectId: widget.projectId,
              payload: drag,
              sectionId: BibleSectionId.location,
              locationName: _model.locationName,
              locationBasePlanId: widget.setId ?? _model.locationBasePlanId,
            ),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: MoodboardStrip.forLocation(
                projectId: widget.projectId,
                locationName: _model.locationName,
                locationBasePlanId: widget.setId ?? _model.locationBasePlanId,
                showTitle: false,
                showCaptions: true,
                draggable: true,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                onPressed: _addPhoto,
                icon: const Icon(Icons.add_photo_alternate_outlined, size: 18),
                label: const Text('Referencia visual'),
              ),
              TextButton(
                onPressed: () async {
                  await widget.onSave(_model);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Localización guardada')),
                    );
                  }
                },
                child: const Text('Guardar'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
