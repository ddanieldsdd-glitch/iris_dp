import 'package:flutter/material.dart';

import '../../../core/database/app_database.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/visual_bible/moodboard_association.dart';
import '../visual_bible_completion.dart';
import '../visual_bible_model.dart';
import 'bible_navigation_scope.dart';

/// Snapshot reactivo de los elementos hijos que completan la Biblia legacy.
class BibleContentSnapshot {
  final List<MoodboardImage> moodboard;
  final List<CameraTest> cameraTests;
  final List<VisualBibleColorBlock> colorBlocks;
  final List<VisualBibleLocationRef> locationRefs;
  final List<LightingSetup> lightingSetups;

  const BibleContentSnapshot({
    this.moodboard = const [],
    this.cameraTests = const [],
    this.colorBlocks = const [],
    this.locationRefs = const [],
    this.lightingSetups = const [],
  });

  int completionCountFor(String sectionId) => switch (sectionId) {
    BibleSectionId.moodboard => moodboard.length,
    BibleSectionId.cameraTests => cameraTests.length,
    BibleSectionId.colorImage => colorBlocks.length,
    BibleSectionId.location => locationRefs.length,
    BibleSectionId.lighting => lightingSetups.length,
    _ => 0,
  };

  int refsForSection(String sectionId) => moodboard
      .where(
        (img) => MoodboardAssociation.visibleInSection(
          category: img.category,
          assignedSections: MoodboardAssociation.decodeSections(img.assignedSections),
          sectionId: sectionId,
        ),
      )
      .length;

  double sectionCompletion(VisualBibleData data, String sectionId) =>
      bibleSectionCompletionExtended(
        data: data,
        sectionId: sectionId,
        moodboardCount: moodboard.length,
        cameraTestCount: cameraTests.length,
        colorBlockCount: colorBlocks.length,
        locationRefCount: locationRefs.length,
        lightingSetupCount: lightingSetups.length,
        sectionRefsCount: refsForSection(sectionId),
      );
}

/// Une los streams ya existentes sin introducir persistencia adicional.
class BibleContentSnapshotBuilder extends StatelessWidget {
  final AppDatabase database;
  final int projectId;
  final int bibleId;
  final Widget Function(BuildContext context, BibleContentSnapshot snapshot)
  builder;

  const BibleContentSnapshotBuilder({
    super.key,
    required this.database,
    required this.projectId,
    required this.bibleId,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<MoodboardImage>>(
      stream: database.watchMoodboardImages(projectId),
      initialData: const [],
      builder: (context, moodboardSnap) => StreamBuilder<List<CameraTest>>(
        stream: database.watchCameraTestsForBible(bibleId),
        initialData: const [],
        builder: (context, testsSnap) =>
            StreamBuilder<List<VisualBibleColorBlock>>(
              stream: database.watchColorBlocksForBible(bibleId),
              initialData: const [],
              builder: (context, colorsSnap) =>
                  StreamBuilder<List<VisualBibleLocationRef>>(
                    stream: database.watchLocationRefsForBible(bibleId),
                    initialData: const [],
                    builder: (context, locationsSnap) =>
                        StreamBuilder<List<LightingSetup>>(
                          stream: database.watchLightingSetupsForBible(bibleId),
                          initialData: const [],
                          builder: (context, lightingSnap) => builder(
                            context,
                            BibleContentSnapshot(
                              moodboard: moodboardSnap.data ?? const [],
                              cameraTests: testsSnap.data ?? const [],
                              colorBlocks: colorsSnap.data ?? const [],
                              locationRefs: locationsSnap.data ?? const [],
                              lightingSetups: lightingSnap.data ?? const [],
                            ),
                          ),
                        ),
                  ),
            ),
      ),
    );
  }
}

class BibleOverviewSection extends StatelessWidget {
  final VisualBibleData data;
  final Project? project;
  final List<BibleSectionDefinition> definitions;
  final BibleContentSnapshot snapshot;
  final ValueChanged<String> onOpenSection;

  const BibleOverviewSection({
    super.key,
    required this.data,
    required this.project,
    required this.definitions,
    required this.snapshot,
    required this.onOpenSection,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final sectionIds = definitions
        .where(
          (def) =>
              !def.isHidden &&
              def.id != BibleSectionId.settings &&
              BibleSectionId.all.contains(def.id),
        )
        .map((def) => def.id)
        .toList();
    final progress = bibleOverallCompletion(
      data: data,
      sectionIds: sectionIds,
      moodboardCount: snapshot.moodboard.length,
      cameraTestCount: snapshot.cameraTests.length,
      colorBlockCount: snapshot.colorBlocks.length,
      locationRefCount: snapshot.locationRefs.length,
      lightingSetupCount: snapshot.lightingSetups.length,
      sectionRefsCount: snapshot.refsForSection,
    );
    final incomplete =
        definitions
            .where(
              (def) =>
                  !def.isHidden &&
                  def.id != BibleSectionId.settings &&
                  BibleSectionId.all.contains(def.id) &&
                  snapshot.sectionCompletion(data, def.id) < 0.85,
            )
            .toList()
          ..sort(
            (a, b) => snapshot
                .sectionCompletion(data, a.id)
                .compareTo(snapshot.sectionCompletion(data, b.id)),
          );

    return ColoredBox(
      color: palette.background,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Resumen', style: AppTypography.titleLarge(palette)),
                const SizedBox(height: 6),
                Text(
                  project?.name.trim().isNotEmpty == true
                      ? 'Estado de la Biblia de ${project!.name.trim()}'
                      : 'Estado general de la Biblia de Fotografía',
                  style: AppTypography.bodyMedium(
                    palette,
                  ).copyWith(color: palette.textSecondary),
                ),
                const SizedBox(height: AppSpacing.xl),
                _ProgressCard(
                  progress: progress,
                  completed: sectionIds
                      .where(
                        (id) => snapshot.sectionCompletion(data, id) >= 0.85,
                      )
                      .length,
                  total: sectionIds.length,
                  palette: palette,
                  latestRef: snapshot.moodboard.isNotEmpty
                      ? snapshot.moodboard.last
                      : null,
                ),
                const SizedBox(height: AppSpacing.lg),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final w = constraints.maxWidth;
                    final columns = w >= 780 ? 4 : (w >= 520 ? 2 : 1);
                    final aspect = columns == 4
                        ? 1.65
                        : columns == 2
                            ? 2.0
                            : 3.2;
                    return GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: columns,
                      crossAxisSpacing: AppSpacing.md,
                      mainAxisSpacing: AppSpacing.md,
                      childAspectRatio: aspect,
                      children: [
                        _CountCard(
                          icon: Icons.photo_library_outlined,
                          label: 'Referencias',
                          count: snapshot.moodboard.length,
                          onTap: () => onOpenSection(BibleSectionId.moodboard),
                        ),
                        _CountCard(
                          icon: Icons.science_outlined,
                          label: 'Pruebas',
                          count: snapshot.cameraTests.length,
                          onTap: () =>
                              onOpenSection(BibleSectionId.cameraTests),
                        ),
                        _CountCard(
                          icon: Icons.palette_outlined,
                          label: 'Bloques de color',
                          count: snapshot.colorBlocks.length,
                          onTap: () => onOpenSection(BibleSectionId.colorImage),
                        ),
                        _CountCard(
                          icon: Icons.location_on_outlined,
                          label: 'Localizaciones',
                          count: snapshot.locationRefs.length,
                          onTap: () => onOpenSection(BibleSectionId.location),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: AppSpacing.xl),
                Text(
                  'Siguiente por completar',
                  style: AppTypography.titleMedium(palette),
                ),
                const SizedBox(height: AppSpacing.sm),
                if (incomplete.isEmpty)
                  const _EmptyMessage(
                    icon: Icons.task_alt,
                    text: 'Las pantallas activas están completas.',
                  )
                else
                  ...incomplete
                      .take(5)
                      .map(
                        (def) => _SectionProgressTile(
                          definition: def,
                          progress: snapshot.sectionCompletion(data, def.id),
                          onTap: () => onOpenSection(def.id),
                        ),
                      ),
                const SizedBox(height: AppSpacing.xl),
                Text(
                  'Elementos clave',
                  style: AppTypography.titleMedium(palette),
                ),
                const SizedBox(height: AppSpacing.sm),
                _KeyItems(snapshot: snapshot, onOpenSection: onOpenSection),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProgressCard extends StatelessWidget {
  final double progress;
  final int completed;
  final int total;
  final AppPalette palette;
  final MoodboardImage? latestRef;

  const _ProgressCard({
    required this.progress,
    required this.completed,
    required this.total,
    required this.palette,
    this.latestRef,
  });

  @override
  Widget build(BuildContext context) {
    final percent = (progress * 100).round();
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            palette.surfaceElevated,
            palette.surface.withValues(alpha: 0.85),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: palette.accent.withValues(alpha: 0.25)),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: palette.accent.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          SizedBox(
            width: 72,
            height: 72,
            child: Stack(
              fit: StackFit.expand,
              children: [
                CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 8,
                  backgroundColor: palette.surfaceOverlay,
                  color: palette.accent,
                ),
                Center(
                  child: Text(
                    '$percent%',
                    style: AppTypography.mono(palette).copyWith(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Progreso de la biblia',
                  style: AppTypography.titleMedium(palette),
                ),
                const SizedBox(height: 4),
                Text(
                  '$completed de $total pantallas con contenido orientativo o refs',
                  style: AppTypography.bodyMedium(
                    palette,
                  ).copyWith(color: palette.textSecondary),
                ),
                if (latestRef != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Última referencia añadida al moodboard',
                    style: AppTypography.caption(palette).copyWith(
                      color: palette.textTertiary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CountCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final int count;
  final VoidCallback onTap;

  const _CountCard({
    required this.icon,
    required this.label,
    required this.count,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Material(
      color: palette.surfaceElevated,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            border: Border.all(color: palette.accent.withValues(alpha: 0.15)),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: palette.accent, size: 20),
              const SizedBox(height: 8),
              Text(
                '$count',
                style: AppTypography.mono(palette).copyWith(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.caption(palette),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionProgressTile extends StatelessWidget {
  final BibleSectionDefinition definition;
  final double progress;
  final VoidCallback onTap;

  const _SectionProgressTile({
    required this.definition,
    required this.progress,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Material(
      color: palette.surfaceElevated,
      child: ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      leading: Icon(bibleIconFromKey(definition.iconKey)),
      title: Text(definition.label),
      subtitle: LinearProgressIndicator(
        value: progress,
        minHeight: 4,
        borderRadius: BorderRadius.circular(4),
        backgroundColor: palette.surfaceOverlay,
        color: palette.accent,
      ),
      trailing: Text('${(progress * 100).round()}%'),
      onTap: onTap,
    ),
    );
  }
}

class _KeyItems extends StatelessWidget {
  final BibleContentSnapshot snapshot;
  final ValueChanged<String> onOpenSection;

  const _KeyItems({required this.snapshot, required this.onOpenSection});

  @override
  Widget build(BuildContext context) {
    final items = <({String label, String detail, String sectionId})>[
      if (snapshot.cameraTests.isNotEmpty)
        (
          label: snapshot.cameraTests.last.testName,
          detail: 'Prueba de cámara',
          sectionId: BibleSectionId.cameraTests,
        ),
      if (snapshot.lightingSetups.isNotEmpty)
        (
          label: snapshot.lightingSetups.last.setupName,
          detail: 'Esquema de iluminación',
          sectionId: BibleSectionId.lighting,
        ),
      if (snapshot.colorBlocks.isNotEmpty)
        (
          label: snapshot.colorBlocks.last.blockName,
          detail: 'Bloque de color',
          sectionId: BibleSectionId.colorImage,
        ),
      if (snapshot.locationRefs.isNotEmpty)
        (
          label: snapshot.locationRefs.last.locationName,
          detail: 'Referencia de localización',
          sectionId: BibleSectionId.location,
        ),
      if (snapshot.moodboard.isNotEmpty)
        (
          label: snapshot.moodboard.last.caption?.trim().isNotEmpty == true
              ? snapshot.moodboard.last.caption!.trim()
              : 'Referencia visual',
          detail:
              snapshot.moodboard.last.filmReference?.trim().isNotEmpty == true
              ? snapshot.moodboard.last.filmReference!.trim()
              : 'Moodboard',
          sectionId: BibleSectionId.moodboard,
        ),
    ];
    if (items.isEmpty) {
      return const _EmptyMessage(
        icon: Icons.auto_awesome_outlined,
        text: 'Añade referencias, pruebas o setups para verlos aquí.',
      );
    }
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: items
          .map(
            (item) => ActionChip(
              avatar: const Icon(Icons.arrow_outward, size: 16),
              label: Text('${item.label} · ${item.detail}'),
              onPressed: () => onOpenSection(item.sectionId),
            ),
          )
          .toList(),
    );
  }
}

class _EmptyMessage extends StatelessWidget {
  final IconData icon;
  final String text;

  const _EmptyMessage({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: palette.surface,
        border: Border.all(color: palette.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: palette.textSecondary),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(text, style: TextStyle(color: palette.textSecondary)),
          ),
        ],
      ),
    );
  }
}
