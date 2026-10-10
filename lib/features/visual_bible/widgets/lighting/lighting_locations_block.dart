import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/database/database_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/visual_bible/bible_palette.dart';
import '../../../../shared/visual_bible/bible_section_ids.dart';
import '../../../../shared/visual_bible/lighting_metrics.dart';
import '../../../../shared/visual_bible/narrative_card_kind.dart';
import '../../services/lighting_narrative_cards_service.dart';
import '../../visual_bible_model.dart';
import '../bible_palette_widget.dart';
import '../bible_point_images.dart';
import '../bible_point_panel.dart';
import '../narrative_deck/narrative_card_detail.dart';
import 'lighting_metrics_widget.dart';

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

Map<String, dynamic> _meta(VisualBibleNarrativeCard? card) {
  final raw = card?.metaJson;
  if (raw == null || raw.isEmpty) return {};
  try {
    final decoded = jsonDecode(raw);
    if (decoded is Map<String, dynamic>) return decoded;
  } catch (_) {}
  return {};
}

List<int> _imageIds(Map<String, dynamic> meta) => [
  if (meta['imageIds'] is List)
    for (final id in meta['imageIds'] as List)
      if (id is num) id.toInt(),
];

LightingMetrics _metrics(Map<String, dynamic> meta) =>
    meta.containsKey('light')
    ? LightingMetrics.fromJson(meta['light'])
    : const LightingMetrics();

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
  final LightingSiteGroup group;
  final Map<int, String> paths;
  final VoidCallback onTap;

  const _SiteTile({
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
      final meta = _meta(card);
      final ids = [
        if (card?.coverMoodboardImageId != null) card!.coverMoodboardImageId!,
        ..._imageIds(meta),
      ];
      cover ??= ids.map((id) => paths[id]).whereType<String>().firstOrNull;
      if (metrics.isEmpty) metrics = _metrics(meta);
      if ((card?.body ?? '').trim().isNotEmpty || ids.isNotEmpty) written++;
    }
    final zones = group.sets.where((s) => !group.isWholeSite(s)).length;
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
              child: cover == null
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
          'Luz de la localización',
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
                      Text(
                        group.name,
                        style: AppTypography.displayMedium(palette),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      for (final set in group.sets)
                        if (group.cardBySet[set.id] != null)
                          Padding(
                            padding: const EdgeInsets.only(
                              bottom: AppSpacing.xl,
                            ),
                            child: _SetLight(
                              key: ValueKey('set_light_${set.id}'),
                              projectId: projectId,
                              bibleId: bibleId,
                              title: group.isWholeSite(set)
                                  ? 'Toda la localización'
                                  : set.locationName,
                              card: group.cardBySet[set.id]!,
                              globalMetrics: globalMetrics,
                              technicalPanelBuilder: technicalPanelBuilder,
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

class _SetLight extends ConsumerStatefulWidget {
  final int projectId;
  final int bibleId;
  final String title;
  final VisualBibleNarrativeCard card;
  final LightingMetrics? globalMetrics;
  final Widget Function(NarrativeCardModel card)? technicalPanelBuilder;

  const _SetLight({
    super.key,
    required this.projectId,
    required this.bibleId,
    required this.title,
    required this.card,
    this.globalMetrics,
    this.technicalPanelBuilder,
  });

  @override
  ConsumerState<_SetLight> createState() => _SetLightState();
}

class _SetLightState extends ConsumerState<_SetLight> {
  Timer? _debounce;
  String? _pendingBody;

  AppDatabase get _db => ref.read(databaseProvider);

  /// Guarda sobre la fila más reciente: texto y meta se editan por separado.
  Future<void> _write({String? body, Map<String, dynamic>? metaPatch}) async {
    final fresh = await _db.getNarrativeCard(widget.card.id);
    if (fresh == null) return;
    final meta = {..._meta(fresh), ...?metaPatch};
    await _db.updateNarrativeCard(
      fresh.copyWith(
        body: body == null
            ? Value(fresh.body)
            : Value(body.trim().isEmpty ? null : body.trim()),
        metaJson: Value(meta.isEmpty ? null : jsonEncode(meta)),
      ),
    );
  }

  void _typed(String text) {
    _pendingBody = text;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), _flush);
  }

  void _flush() {
    final body = _pendingBody;
    _pendingBody = null;
    if (body != null) _write(body: body);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _flush();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final card = widget.card;
    final meta = _meta(card);
    final body = AppTypography.bodyLarge(palette);
    final label = BiblePointPanel.labelStyle(palette);

    return BiblePointPanel(
      label: widget.title,
      icon: Icons.wb_twilight_outlined,
      trailing: TextButton(
        onPressed: () => NarrativeCardDetailPage.open(
          context,
          projectId: widget.projectId,
          bibleId: widget.bibleId,
          cardId: card.id,
          technicalPanel: widget.technicalPanelBuilder?.call(
            NarrativeCardModel.fromRow(card),
          ),
        ),
        child: const Text('Ficha técnica'),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('CÓMO LA IMAGINAMOS', style: label),
          const SizedBox(height: 6),
          BiblePointImages(
            projectId: widget.projectId,
            bibleId: widget.bibleId,
            sectionId: BibleSectionId.lighting,
            imageIds: _imageIds(meta),
            height: 180,
            onChanged: (ids) => _write(metaPatch: {'imageIds': ids}),
          ),
          const SizedBox(height: AppSpacing.md),
          TextFormField(
            initialValue: card.body ?? '',
            minLines: 2,
            maxLines: null,
            style: body,
            decoration: InputDecoration(
              hintText:
                  'Qué luz tiene este lugar en la película y por qué: de '
                  'dónde viene, qué deja en sombra, qué cambia de día a '
                  'noche…',
              hintStyle: body.copyWith(color: palette.textTertiary),
              isDense: true,
              filled: false,
              contentPadding: EdgeInsets.zero,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
            ),
            onChanged: _typed,
          ),
          const SizedBox(height: AppSpacing.lg),
          LightingMetricsWidget(
            value: _metrics(meta),
            reference: widget.globalMetrics,
            onChanged: (next) => _write(metaPatch: {'light': next.toJson()}),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text('PALETA DE ESTA LUZ', style: label),
          const SizedBox(height: 6),
          BiblePaletteWidget(
            projectId: widget.projectId,
            bibleId: widget.bibleId,
            sectionId: BibleSectionId.lighting,
            swatchSize: 56,
            preferredImageIds: _imageIds(meta),
            colors: BiblePaletteColor.listFrom(meta['palette']),
            onChanged: (colors) => _write(
              metaPatch: {'palette': BiblePaletteColor.toJsonList(colors)},
            ),
          ),
        ],
      ),
    );
  }
}
