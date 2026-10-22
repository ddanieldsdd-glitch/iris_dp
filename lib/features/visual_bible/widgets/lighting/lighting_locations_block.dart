import '../../../locations/location_admin.dart';
import '../../../locations/location_manage_menu.dart';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/database/database_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/visual_bible/bible_section_ids.dart';
import '../../../../shared/visual_bible/lighting_metrics.dart';
import '../../../../shared/visual_bible/narrative_card_kind.dart';
import '../../services/lighting_narrative_cards_service.dart';
import '../../visual_bible_model.dart';
import '../bible_point_panel.dart';
import '../narrative_deck/narrative_card_detail.dart';
import 'lighting_card_view.dart';

/// Una localización con las fichas de luz de sus sets.
class LightingSiteGroup {
  /// Nulo en sets que no cuelgan de ninguna localización.
  final LocationSite? site;
  final String name;

  /// Los sets, con la localización entera primero.
  final List<LocationBasePlan> sets;
  final Map<int, VisualBibleNarrativeCard> cardBySet;

  const LightingSiteGroup({
    required this.site,
    required this.name,
    required this.sets,
    required this.cardBySet,
  });

  /// El set es la localización entera, no una zona de ella.
  bool isWholeSite(LocationBasePlan set) =>
      set.locationName.trim().toLowerCase() == name.trim().toLowerCase();

  /// Sets sueltos que repiten esta localización (mismo nombre, sin
  /// localización): una copia que conviene unir, no un set más.
  List<LocationBasePlan> get looseTwins => [
    if (site != null)
      for (final set in sets)
        if (set.siteId != site!.id && isWholeSite(set)) set,
  ];

  /// Los sets que se enseñan: sin las copias sueltas.
  List<LocationBasePlan> get shownSets {
    final twins = looseTwins;
    return [
      for (final set in sets)
        if (!twins.contains(set)) set,
    ];
  }

  /// Título de la ficha de un set: el nombre limpio; « · toda la
  /// localización» solo si hay además otros sets.
  String titleOf(LocationBasePlan set) {
    if (!isWholeSite(set)) return set.locationName;
    return shownSets.length > 1 ? '$name · toda la localización' : name;
  }

  /// Agrupa los sets por localización: cada localización sale una vez.
  static List<LightingSiteGroup> group({
    required List<LocationSite> sites,
    required List<LocationBasePlan> sets,
    required List<VisualBibleNarrativeCard> cards,
  }) {
    final cardBySet = {
      for (final card in cards)
        if (card.locationBasePlanId != null) card.locationBasePlanId!: card,
    };
    final groups = <LightingSiteGroup>[];
    for (final site in sites) {
      final own = [
        for (final set in sets)
          if (set.siteId == site.id) set,
      ];
      if (own.isEmpty) continue;
      own.sort((a, b) {
        bool whole(LocationBasePlan s) =>
            s.locationName.trim().toLowerCase() ==
            site.name.trim().toLowerCase();
        if (whole(a) != whole(b)) return whole(a) ? -1 : 1;
        return a.locationName.compareTo(b.locationName);
      });
      groups.add(
        LightingSiteGroup(
          site: site,
          name: site.name,
          sets: own,
          cardBySet: cardBySet,
        ),
      );
    }
    final siteIds = {for (final s in sites) s.id};
    for (final set in sets) {
      if (set.siteId != null && siteIds.contains(set.siteId)) continue;
      // Un set suelto que se llama como una localización es esa misma
      // localización repetida: va con ella, no en otra tarjeta.
      final twin = groups
          .where(
            (g) =>
                g.site != null &&
                g.name.trim().toLowerCase() ==
                    set.locationName.trim().toLowerCase(),
          )
          .firstOrNull;
      if (twin != null) {
        twin.sets.add(set);
        continue;
      }
      groups.add(
        LightingSiteGroup(
          site: null,
          name: set.locationName,
          sets: [set],
          cardBySet: cardBySet,
        ),
      );
    }
    return groups;
  }
}

/// «Luz por localización»: cada localización una sola vez, con su imagen y
/// sus métricas a la vista; al abrirla, sus sets uno debajo de otro.
class LightingLocationsBlock extends ConsumerStatefulWidget {
  final int projectId;
  final int bibleId;

  /// Métricas generales del proyecto, para comparar.
  final LightingMetrics? globalMetrics;

  /// Panel técnico (esquemas, notas de set) de la ficha completa.
  final Widget Function(NarrativeCardModel card)? technicalPanelBuilder;

  const LightingLocationsBlock({
    super.key,
    required this.projectId,
    required this.bibleId,
    this.globalMetrics,
    this.technicalPanelBuilder,
  });

  @override
  ConsumerState<LightingLocationsBlock> createState() =>
      _LightingLocationsBlockState();
}

class _LightingLocationsBlockState
    extends ConsumerState<LightingLocationsBlock> {
  @override
  void initState() {
    super.initState();
    // Crea la ficha de los sets nuevos y funde las repetidas.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      LightingNarrativeCardsService.ensureSeeded(
        db: ref.read(databaseProvider),
        bibleId: widget.bibleId,
        projectId: widget.projectId,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final db = ref.watch(databaseProvider);
    return BiblePointPanel(
      label: 'Luz por localización',
      icon: Icons.place_outlined,
      child: StreamBuilder<List<LocationSite>>(
        stream: db.watchSitesForProject(widget.projectId),
        builder: (context, siteSnap) => StreamBuilder<List<LocationBasePlan>>(
          stream: db.watchLocationsForProject(widget.projectId),
          builder: (context, setSnap) =>
              StreamBuilder<List<VisualBibleNarrativeCard>>(
                stream: db.watchNarrativeCardsForSection(
                  widget.bibleId,
                  BibleSectionId.lighting,
                  kind: NarrativeCardKind.locationLight,
                ),
                builder: (context, cardSnap) =>
                    StreamBuilder<List<MoodboardImage>>(
                      stream: db.watchMoodboardImages(widget.projectId),
                      builder: (context, imageSnap) {
                        final groups = LightingSiteGroup.group(
                          sites: siteSnap.data ?? const [],
                          sets: setSnap.data ?? const [],
                          cards: cardSnap.data ?? const [],
                        );
                        if (groups.isEmpty) {
                          return Text(
                            'Aún no hay localizaciones en el proyecto. '
                            'Aparecen aquí al crearlas o al importar el guion.',
                            style: AppTypography.caption(palette),
                          );
                        }
                        final paths = {
                          for (final image
                              in imageSnap.data ?? const <MoodboardImage>[])
                            image.id: image.imagePath,
                        };
                        return Wrap(
                          spacing: AppSpacing.md,
                          runSpacing: AppSpacing.md,
                          children: [
                            for (final group in groups)
                              _SiteTile(
                                projectId: widget.projectId,
                                group: group,
                                paths: paths,
                                onTap: () => Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) => LightingSitePage(
                                      projectId: widget.projectId,
                                      bibleId: widget.bibleId,
                                      siteId: group.site?.id,
                                      setId: group.site == null
                                          ? group.sets.first.id
                                          : null,
                                      globalMetrics: widget.globalMetrics,
                                      technicalPanelBuilder:
                                          widget.technicalPanelBuilder,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
              ),
        ),
      ),
    );
  }
}

class _SiteTile extends StatelessWidget {
  final int projectId;
  final LightingSiteGroup group;
  final Map<int, String> paths;
  final VoidCallback onTap;

  const _SiteTile({
    required this.projectId,
    required this.group,
    required this.paths,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    // La primera imagen y las primeras métricas que haya entre sus sets.
    String? cover;
    var metrics = const LightingMetrics();
    var written = 0;
    for (final set in group.sets) {
      final card = group.cardBySet[set.id];
      if (card == null) continue;
      final page = lightingCardPageOf(card);
      final ids = [
        if (card.coverMoodboardImageId != null) card.coverMoodboardImageId!,
        if (page.firstImageId != null) page.firstImageId!,
      ];
      cover ??= ids.map((id) => paths[id]).whereType<String>().firstOrNull;
      if (metrics.isEmpty) metrics = page.metrics;
      if ((card.body ?? '').trim().isNotEmpty || ids.isNotEmpty) written++;
    }
    final zones = group.shownSets.where((s) => !group.isWholeSite(s)).length;
    final ratio = metrics.ratioOption;

    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Container(
        width: 260,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: palette.background.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: palette.divider),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 130,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  cover == null
                      ? ColoredBox(
                          color: Colors.black26,
                          child: Icon(
                            Icons.add_photo_alternate_outlined,
                            color: palette.textTertiary,
                          ),
                        )
                      : Image.file(
                          File(cover),
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) =>
                              const ColoredBox(color: Colors.black26),
                        ),
                  Positioned(
                    top: 4,
                    right: 4,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.5),
                        shape: BoxShape.circle,
                      ),
                      child: LocationManageMenu(
                        projectId: projectId,
                        site: group.site,
                        looseSet: group.site == null ? group.sets.first : null,
                        iconColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    group.name,
                    style: AppTypography.titleMedium(palette),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    [
                      if (zones > 0) '$zones ${zones == 1 ? 'set' : 'sets'}',
                      written == 0 ? 'Sin desarrollar' : 'Con luz pensada',
                    ].join(' · '),
                    style: AppTypography.caption(palette),
                  ),
                  if (metrics.kelvin != null || ratio != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        if (metrics.kelvin != null) ...[
                          Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: Color(0xFF000000 | metrics.color!),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${metrics.kelvin} K',
                            style: AppTypography.mono(palette),
                          ),
                          const SizedBox(width: 12),
                        ],
                        if (ratio != null)
                          Text(
                            ratio.label,
                            style: AppTypography.mono(
                              palette,
                            ).copyWith(color: palette.accent),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// La luz de una localización: sus sets, cada uno con cómo lo imaginamos
/// (imágenes), por qué (texto), su color y contraste y su paleta.
class LightingSitePage extends ConsumerWidget {
  final int projectId;
  final int bibleId;
  final int? siteId;

  /// Para un set suelto, sin localización.
  final int? setId;
  final LightingMetrics? globalMetrics;
  final Widget Function(NarrativeCardModel card)? technicalPanelBuilder;

  const LightingSitePage({
    super.key,
    required this.projectId,
    required this.bibleId,
    this.siteId,
    this.setId,
    this.globalMetrics,
    this.technicalPanelBuilder,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final db = ref.watch(databaseProvider);
    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        backgroundColor: palette.background,
        title: Text(
          'Luz por localización',
          style: AppTypography.bodyMedium(
            palette,
          ).copyWith(fontWeight: FontWeight.w600),
        ),
      ),
      body: StreamBuilder<List<LocationSite>>(
        stream: db.watchSitesForProject(projectId),
        builder: (context, siteSnap) => StreamBuilder<List<LocationBasePlan>>(
          stream: db.watchLocationsForProject(projectId),
          builder: (context, setSnap) =>
              StreamBuilder<List<VisualBibleNarrativeCard>>(
                stream: db.watchNarrativeCardsForSection(
                  bibleId,
                  BibleSectionId.lighting,
                  kind: NarrativeCardKind.locationLight,
                ),
                builder: (context, cardSnap) {
                  final groups = LightingSiteGroup.group(
                    sites: siteSnap.data ?? const [],
                    sets: setSnap.data ?? const [],
                    cards: cardSnap.data ?? const [],
                  );
                  final group = groups
                      .where(
                        (g) => siteId != null
                            ? g.site?.id == siteId
                            : g.site == null && g.sets.first.id == setId,
                      )
                      .firstOrNull;
                  if (group == null) return const SizedBox.shrink();
                  return ListView(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    children: [
                      for (final twin in group.looseTwins)
                        Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                          child: LooseTwinNotice(
                            projectId: projectId,
                            twin: twin,
                            into: group.shownSets
                                .where(group.isWholeSite)
                                .firstOrNull,
                          ),
                        ),
                      for (final set in group.shownSets)
                        if (group.cardBySet[set.id] != null)
                          Padding(
                            padding: const EdgeInsets.only(
                              bottom: AppSpacing.xl,
                            ),
                            child: LightingCardView(
                              key: ValueKey('set_light_${set.id}'),
                              projectId: projectId,
                              bibleId: bibleId,
                              cardId: group.cardBySet[set.id]!.id,
                              fixedTitle: group.titleOf(set),
                              globalMetrics: globalMetrics,
                              actions: [
                                // Esquemas y notas técnicas del set.
                                TextButton(
                                  onPressed: () => NarrativeCardDetailPage.open(
                                    context,
                                    projectId: projectId,
                                    bibleId: bibleId,
                                    cardId: group.cardBySet[set.id]!.id,
                                    technicalPanel: technicalPanelBuilder?.call(
                                      NarrativeCardModel.fromRow(
                                        group.cardBySet[set.id]!,
                                      ),
                                    ),
                                  ),
                                  child: const Text(
                                    'Ficha técnica',
                                    style: TextStyle(color: Colors.white70),
                                  ),
                                ),
                              ],
                            ),
                          ),
                    ],
                  );
                },
              ),
        ),
      ),
    );
  }
}

/// Aviso de una copia suelta de la localización (un set sin localización
/// que se llama igual), con el botón para unirla.
class LooseTwinNotice extends ConsumerWidget {
  final int projectId;
  final LocationBasePlan twin;

  /// El set bueno en el que se une; nulo si no lo hay.
  final LocationBasePlan? into;

  const LooseTwinNotice({
    super.key,
    required this.projectId,
    required this.twin,
    required this.into,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final db = ref.watch(databaseProvider);
    final admin = LocationAdmin(db);
    return FutureBuilder<LocationUsage>(
      future: admin.usageOfSet(twin.id),
      builder: (context, snap) {
        final usage = snap.data;
        return Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: palette.accent.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: palette.accent.withValues(alpha: 0.4)),
          ),
          child: Row(
            children: [
              Icon(Icons.content_copy_outlined, color: palette.accent),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  'Hay una copia suelta de «${twin.locationName}» con su '
                  'propia ficha'
                  '${usage != null && usage.inUse ? ' (la usan ${usage.summary})' : ''}. '
                  'Al unirla, todo pasa a esta localización y la copia '
                  'desaparece.',
                  style: AppTypography.bodyMedium(palette),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              FilledButton(
                onPressed: into == null
                    ? null
                    : () => admin.mergeSetInto(twin.id, into!.id),
                child: const Text('Unirla'),
              ),
            ],
          ),
        );
      },
    );
  }
}
