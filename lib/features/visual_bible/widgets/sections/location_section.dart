import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:drift/drift.dart' as drift;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/database/database_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/clipboard_image_reader.dart';
import '../../../../core/utils/media_storage.dart';
import '../../bible_paste_helpers.dart';
import '../../bible_section_fields.dart';
import '../../services/color_extraction_service.dart';
import '../../visual_bible_model.dart';
import '../../../locations/location_form_sheet.dart';
import '../../../locations/location_site_form_sheet.dart';
import '../../../locations/site_place.dart';
import '../../../../core/weather/weather_models.dart';
import '../../../../core/weather/weather_service.dart';
import '../../../../core/weather/weather_summary.dart';
import '../../../../shared/visual_bible/narrative_card_kind.dart';
import '../../../locations/location_manage_menu.dart';
import '../lighting/lighting_card_view.dart';
import '../lighting/lighting_locations_block.dart';
import '../bible_navigation_scope.dart';
import '../bible_paste_zone.dart';
import '../moodboard_drag.dart';
import '../bible_visual_color_sheet.dart';
import '../moodboard_strip.dart';
import '../../moodboard_helpers.dart';
import '../../services/lighting_narrative_cards_service.dart';
import '../../../../shared/visual_bible/bible_section_ids.dart';
import '../narrative_deck/narrative_card_detail.dart';
import '../bible_screen_hero.dart';

/// Localización — layout Stitch (hero + solar + atmósfera + staging).
class LocationSection extends ConsumerStatefulWidget {
  final int projectId;
  final int bibleId;
  final String? sectionContentJson;

  const LocationSection({
    super.key,
    required this.projectId,
    required this.bibleId,
    this.sectionContentJson,
  });

  @override
  ConsumerState<LocationSection> createState() => _LocationSectionState();
}

class _LocationSectionState extends ConsumerState<LocationSection> {
  Map<String, dynamic> _getCustom() {
    final raw = widget.sectionContentJson;
    if (raw == null || raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return {};
      final valuesRaw = decoded['values'] ?? decoded['_values'];
      if (valuesRaw is Map) {
        final vals = Map<String, dynamic>.from(valuesRaw);
        if (vals['locationData'] is String) {
          final parsed = jsonDecode(vals['locationData'] as String);
          if (parsed is Map<String, dynamic>) return parsed;
        }
        return vals;
      }
    } catch (_) {}
    return {};
  }

  Future<void> _updateCustom(Map<String, dynamic> update) async {
    final current = _getCustom();
    final newData = {...current, ...update};
    final db = ref.read(databaseProvider);
    final def =
        await (db.select(db.bibleSectionDefinitions)..where(
              (d) =>
                  d.bibleId.equals(widget.bibleId) &
                  d.id.equals(BibleSectionId.location),
            ))
            .getSingleOrNull();
    if (def == null) return;
    final fields = BibleSectionFieldsConfig.parse(
      def.contentJson,
      BibleSectionId.location,
    );
    final values = BibleSectionFieldsConfig.parseValues(def.contentJson);
    values['locationData'] = jsonEncode(newData);
    await db.upsertBibleSectionDefinition(
      def.copyWith(
        contentJson: drift.Value(
          BibleSectionFieldsConfig.encode(fields, values: values),
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  Map<String, dynamic> _planExtras(int planId) {
    final custom = _getCustom();
    final byPlan = custom['byPlan'];
    if (byPlan is Map && byPlan['$planId'] is Map) {
      return Map<String, dynamic>.from(byPlan['$planId'] as Map);
    }
    return {};
  }

  Future<void> _updatePlanExtras(int planId, Map<String, dynamic> patch) async {
    final custom = _getCustom();
    final byPlan = Map<String, dynamic>.from(
      (custom['byPlan'] as Map?)?.map((k, v) => MapEntry('$k', v)) ?? {},
    );
    final current = Map<String, dynamic>.from(
      (byPlan['$planId'] as Map?) ?? {},
    );
    byPlan['$planId'] = {...current, ...patch};
    await _updateCustom({'byPlan': byPlan, 'selectedPlanId': planId});
  }

  /// La localización abierta: `site:<id>` o `set:<id>` (un set suelto).
  /// Nulo = se ven todas, en tarjetas.
  String? _open;

  static String _keyOf(LightingSiteGroup group) => group.site != null
      ? 'site:${group.site!.id}'
      : 'set:${group.sets.first.id}';

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final db = ref.watch(databaseProvider);

    return StreamBuilder<List<LocationSite>>(
      stream: db.watchSitesForProject(widget.projectId),
      builder: (context, siteSnap) => StreamBuilder<List<LocationBasePlan>>(
        stream: db.watchLocationsForProject(widget.projectId),
        builder: (context, locSnap) =>
            StreamBuilder<List<VisualBibleLocationRef>>(
              stream: db.watchLocationRefsForBible(widget.bibleId),
              builder: (context, refSnap) =>
                  StreamBuilder<List<VisualBibleNarrativeCard>>(
                    stream: db.watchNarrativeCardsForSection(
                      widget.bibleId,
                      BibleSectionId.lighting,
                      kind: NarrativeCardKind.locationLight,
                    ),
                    builder: (context, cardSnap) => StreamBuilder<List<Scene>>(
                      stream: db.watchScenesForProject(widget.projectId),
                      builder: (context, sceneSnap) {
                        final groups = LightingSiteGroup.group(
                          sites: siteSnap.data ?? const [],
                          sets: locSnap.data ?? const [],
                          cards: cardSnap.data ?? const [],
                        );
                        final open = groups
                            .where((g) => _keyOf(g) == _open)
                            .firstOrNull;
                        return ListView(
                          padding: const EdgeInsets.all(24),
                          children: [
                            BibleSectionHero(
                              projectId: widget.projectId,
                              bibleId: widget.bibleId,
                              sectionId: BibleSectionId.location,
                              title: 'Localización',
                            ),
                            if (open == null)
                              _hub(
                                palette,
                                groups,
                                refSnap.data ?? const [],
                                sceneSnap.data ?? const [],
                              )
                            else
                              ..._page(
                                palette,
                                db,
                                open,
                                refSnap.data ?? const [],
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

  /// Todas las localizaciones, una tarjeta cada una.
  Widget _hub(
    AppPalette palette,
    List<LightingSiteGroup> groups,
    List<VisualBibleLocationRef> refs,
    List<Scene> scenes,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                groups.isEmpty
                    ? 'Aún no hay localizaciones: aparecen al importar el '
                          'guion o al crearlas.'
                    : 'Toca una localización para entrar en ella: ubicación, '
                          'sol, meteorología, su luz y cada uno de sus sets.',
                style: AppTypography.bodyMedium(
                  palette,
                ).copyWith(color: palette.textSecondary),
              ),
            ),
            TextButton.icon(
              onPressed: () => showLocationSiteFormSheet(
                context,
                projectId: widget.projectId,
              ),
              icon: const Icon(Icons.add_location_alt_outlined, size: 18),
              label: const Text('Nueva localización'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 14,
          runSpacing: 14,
          children: [
            for (final group in groups)
              _LocationTile(
                projectId: widget.projectId,
                group: group,
                cover: _coverOf(group, refs),
                scenes: scenes
                    .where(
                      (s) =>
                          (group.site != null &&
                              s.locationSiteId == group.site!.id) ||
                          group.sets.any((set) => set.id == s.locationId),
                    )
                    .length,
                onTap: () => setState(() => _open = _keyOf(group)),
              ),
          ],
        ),
      ],
    );
  }

  /// La primera foto que tenga alguno de sus sets.
  String? _coverOf(LightingSiteGroup group, List<VisualBibleLocationRef> refs) {
    for (final set in group.sets) {
      final extras = _planExtras(set.id);
      final candidates = [
        extras['heroImage'],
        ...?(extras['photos'] as List?),
        set.imagePath,
        for (final r in refs)
          if (r.locationBasePlanId == set.id)
            ...LocationRefModel.fromRow(r).referenceImages,
      ];
      for (final path in candidates) {
        if (path is String && path.isNotEmpty && File(path).existsSync()) {
          return path;
        }
      }
    }
    return null;
  }

  /// La página de una localización: lo suyo y, debajo, cada set.
  List<Widget> _page(
    AppPalette palette,
    AppDatabase db,
    LightingSiteGroup group,
    List<VisualBibleLocationRef> refs,
  ) {
    final site = group.site;
    final refsByPlanId = {
      for (final r in refs)
        if (r.locationBasePlanId != null) r.locationBasePlanId!: r,
    };
    final refsByName = {for (final r in refs) r.locationName: r};
    final wholeCard = group.shownSets
        .map((set) => group.cardBySet[set.id])
        .whereType<VisualBibleNarrativeCard>()
        .firstOrNull;

    return [
      Row(
        children: [
          TextButton.icon(
            onPressed: () => setState(() => _open = null),
            icon: const Icon(Icons.arrow_back, size: 18),
            label: const Text('Todas las localizaciones'),
          ),
          const Spacer(),
          TextButton.icon(
            onPressed: () =>
                BibleNavigationScope.openLocationSet(context, siteId: site?.id),
            icon: const Icon(Icons.open_in_new, size: 16),
            label: const Text('Abrir en Localizaciones'),
          ),
          LocationManageMenu(
            projectId: widget.projectId,
            site: site,
            looseSet: site == null ? group.sets.first : null,
          ),
        ],
      ),
      const SizedBox(height: 4),
      Text(group.name, style: AppTypography.displayMedium(palette)),
      const SizedBox(height: 16),
      for (final twin in group.looseTwins) ...[
        LooseTwinNotice(
          projectId: widget.projectId,
          twin: twin,
          into: group.shownSets.where(group.isWholeSite).firstOrNull,
        ),
        const SizedBox(height: 16),
      ],
      if (site != null)
        _SiteFactsCard(site: site)
      else
        Text(
          'Este set no está dentro de ninguna localización, así que no '
          'tiene ubicación, sol ni meteorología. Mételo en una desde el '
          'menú «⋯» de arriba.',
          style: AppTypography.bodyMedium(
            palette,
          ).copyWith(color: palette.textSecondary),
        ),
      const SizedBox(height: 24),
      Text('LA LUZ DEL LUGAR', style: AppTypography.label(palette)),
      const SizedBox(height: 4),
      Text(
        'Es la misma ficha que «Luz por localización» de Iluminación: lo '
        'que escribas aquí aparece allí.',
        style: AppTypography.caption(palette),
      ),
      const SizedBox(height: 10),
      if (wholeCard != null)
        LightingCardView(
          key: ValueKey('loc_light_${wholeCard.id}'),
          projectId: widget.projectId,
          bibleId: widget.bibleId,
          cardId: wholeCard.id,
          fixedTitle: group.name,
        )
      else
        TextButton.icon(
          onPressed: () async {
            await LightingNarrativeCardsService.ensureSeeded(
              db: db,
              bibleId: widget.bibleId,
              projectId: widget.projectId,
            );
          },
          icon: const Icon(Icons.wb_incandescent_outlined, size: 18),
          label: const Text('Crear la ficha de luz de esta localización'),
        ),
      const SizedBox(height: 28),
      for (final set in group.shownSets) ...[
        Text(
          group.isWholeSite(set)
              ? 'FICHA DE LA LOCALIZACIÓN'
              : 'SET · ${set.locationName.toUpperCase()}',
          style: AppTypography.label(palette),
        ),
        const SizedBox(height: 10),
        Builder(
          builder: (_) {
            final refRow = refsByPlanId[set.id] ?? refsByName[set.locationName];
            final model = refRow != null
                ? LocationRefModel.fromRow(refRow)
                : LocationRefModel(
                    id: 0,
                    bibleId: widget.bibleId,
                    locationName: set.locationName,
                    locationSiteId: set.siteId,
                    locationBasePlanId: set.id,
                  );
            model.locationBasePlanId ??= set.id;
            model.locationSiteId ??= set.siteId;
            return _FeaturedLocation(
              // Cada set con su propia ficha: sin la clave, todas enseñaban
              // lo del primero.
              key: ValueKey('featured_${set.id}'),
              projectId: widget.projectId,
              bibleId: widget.bibleId,
              plan: set,
              siteName: site?.name,
              site: site,
              extras: _planExtras(set.id),
              model: model,
              palette: palette,
              onExtras: (patch) => _updatePlanExtras(set.id, patch),
              onSaveRef: (m) => db.upsertLocationRef(m.toCompanion()),
            );
          },
        ),
        const SizedBox(height: 28),
      ],
      if (site != null)
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => showLocationFormSheet(
              context,
              projectId: widget.projectId,
              siteId: site.id,
            ),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Añadir un set a esta localización'),
          ),
        ),
    ];
  }
}

/// Tarjeta de una localización en la entrada de la pantalla.
class _LocationTile extends StatelessWidget {
  final int projectId;
  final LightingSiteGroup group;
  final String? cover;
  final int scenes;
  final VoidCallback onTap;

  const _LocationTile({
    required this.projectId,
    required this.group,
    required this.cover,
    required this.scenes,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final site = group.site;
    final zones = group.shownSets.where((s) => !group.isWholeSite(s)).length;
    final located = site?.latitude != null && site?.longitude != null;
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Container(
        width: 280,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: palette.surfaceElevated,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: palette.divider),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 140,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  cover == null
                      ? ColoredBox(
                          color: Colors.black26,
                          child: Icon(
                            Icons.place_outlined,
                            color: palette.textTertiary,
                            size: 32,
                          ),
                        )
                      : Image.file(
                          File(cover!),
                          fit: BoxFit.cover,
                          cacheWidth: 600,
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
                        site: site,
                        looseSet: site == null ? group.sets.first : null,
                        iconColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
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
                      if (site == null) 'Set suelto',
                      if (zones > 0) '$zones ${zones == 1 ? 'set' : 'sets'}',
                      '$scenes ${scenes == 1 ? 'escena' : 'escenas'}',
                    ].join(' · '),
                    style: AppTypography.caption(palette),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        located
                            ? Icons.place_outlined
                            : Icons.location_off_outlined,
                        size: 13,
                        color: located ? palette.accent : palette.textTertiary,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          located
                              ? (site!.placeLabel ?? 'Ubicada')
                              : 'Sin ubicar en el mapa',
                          style: AppTypography.caption(palette),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
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

/// Dónde está la localización, cómo llegar, el sol de un día y la
/// previsión. La ubicación es la misma que en la pantalla Localizaciones.
class _SiteFactsCard extends ConsumerStatefulWidget {
  final LocationSite site;

  const _SiteFactsCard({required this.site});

  @override
  ConsumerState<_SiteFactsCard> createState() => _SiteFactsCardState();
}

class _SiteFactsCardState extends ConsumerState<_SiteFactsCard> {
  DateTime _day = DateTime.now();
  Future<WeatherSnapshot?>? _forecast;
  String? _forecastKey;

  static String _iso(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  void _open(String url) =>
      launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final site = widget.site;
    final lat = site.latitude;
    final lon = site.longitude;
    final located = lat != null && lon != null;
    final within = isWithinForecast(_day, DateTime.now());

    if (located && within) {
      final key = '$lat,$lon,${_iso(_day)}';
      if (key != _forecastKey) {
        _forecastKey = key;
        _forecast = ref
            .read(weatherProviderProvider)
            .forecast(latitude: lat, longitude: lon, date: _iso(_day))
            .catchError((Object _) => null);
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SitePlaceCard(site: site),
        if (located) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final (label, url) in locationMapLinks(lat, lon))
                OutlinedButton.icon(
                  onPressed: () => _open(url),
                  icon: const Icon(Icons.open_in_new, size: 15),
                  label: Text(label),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: palette.surfaceElevated,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: palette.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.cloud_outlined, size: 18, color: palette.accent),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Meteorología del ${_day.day}/${_day.month}/${_day.year}',
                        style: AppTypography.bodyLarge(palette),
                      ),
                    ),
                    TextButton(
                      onPressed: () async {
                        final now = DateTime.now();
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _day,
                          firstDate: now,
                          lastDate: now.add(
                            const Duration(days: kForecastHorizonDays - 1),
                          ),
                          helpText: '¿Qué día ruedas aquí?',
                        );
                        if (picked != null) setState(() => _day = picked);
                      },
                      child: const Text('Cambiar día'),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                if (!within)
                  Text(
                    'Solo hay previsión para los próximos '
                    '$kForecastHorizonDays días.',
                    style: AppTypography.caption(palette),
                  )
                else
                  FutureBuilder<WeatherSnapshot?>(
                    future: _forecast,
                    builder: (context, snap) {
                      if (snap.connectionState != ConnectionState.done) {
                        return Text(
                          'Consultando la previsión…',
                          style: AppTypography.caption(palette),
                        );
                      }
                      final forecast = snap.data;
                      if (forecast == null) {
                        return Text(
                          'No se ha podido descargar la previsión (sin '
                          'conexión o sin datos para ese día).',
                          style: AppTypography.caption(palette),
                        );
                      }
                      final lines = weatherSummaryLines(
                        options: const WeatherOptions(
                          sun: false,
                          blueAndGolden: false,
                          hourly: false,
                        ),
                        sun: null,
                        forecast: forecast,
                        utcOffsetSeconds: forecast.utcOffsetSeconds,
                      );
                      return Text(
                        lines.join('\n'),
                        style: AppTypography.bodyMedium(palette),
                      );
                    },
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// Enlaces para abrir unas coordenadas en las apps de mapas.
List<(String, String)> locationMapLinks(double latitude, double longitude) => [
  (
    'Google Maps',
    'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude',
  ),
  ('Waze', 'https://waze.com/ul?ll=$latitude,$longitude&navigate=yes'),
  ('Google Earth', 'https://earth.google.com/web/search/$latitude,$longitude'),
  ('Apple Mapas', 'https://maps.apple.com/?ll=$latitude,$longitude&q=Rodaje'),
];

class _FeaturedLocation extends ConsumerStatefulWidget {
  final int projectId;
  final int bibleId;
  final LocationBasePlan plan;
  final String? siteName;

  /// La localización del set: su ubicación en el mapa se fija aquí o en
  /// la pantalla de Localizaciones, y es la misma.
  final LocationSite? site;
  final Map<String, dynamic> extras;
  final LocationRefModel model;
  final AppPalette palette;
  final Future<void> Function(Map<String, dynamic>) onExtras;
  final Future<void> Function(LocationRefModel) onSaveRef;

  const _FeaturedLocation({
    super.key,
    required this.projectId,
    required this.bibleId,
    required this.plan,
    required this.siteName,
    this.site,
    required this.extras,
    required this.model,
    required this.palette,
    required this.onExtras,
    required this.onSaveRef,
  });

  @override
  ConsumerState<_FeaturedLocation> createState() => _FeaturedLocationState();
}

class _FeaturedLocationState extends ConsumerState<_FeaturedLocation> {
  late LocationRefModel _model;

  @override
  void initState() {
    super.initState();
    _model = widget.model;
  }

  @override
  void didUpdateWidget(covariant _FeaturedLocation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.plan.id != widget.plan.id ||
        oldWidget.model.id != widget.model.id) {
      _model = widget.model;
    }
  }

  Map<String, dynamic> get x => widget.extras;

  String _s(String key, [String fallback = '']) =>
      (x[key] as String?)?.trim().isNotEmpty == true
      ? x[key] as String
      : fallback;

  List<String> _list(String key, List<String> fallback) {
    final raw = x[key];
    if (raw is List && raw.isNotEmpty) {
      return raw.map((e) => e.toString()).toList();
    }
    return fallback;
  }

  List<String> _paletteColors() {
    final raw = x['palette'];
    if (raw is List && raw.isNotEmpty) {
      return raw.map((e) => e.toString()).toList();
    }
    final fromNote = RegExp(r'#([0-9A-Fa-f]{6})')
        .allMatches(_model.colorNote ?? '')
        .map((m) => '#${m.group(1)!.toUpperCase()}')
        .toList();
    if (fromNote.isNotEmpty) return fromNote;
    // Sin colores propios no se inventa una paleta.
    return const [];
  }

  /// Edición rápida de un dato: se guarda con Intro o al cerrar; Esc lo
  /// deja como estaba.
  Future<String?> _quickEdit(
    String title,
    String current, {
    int lines = 1,
  }) async {
    final c = TextEditingController(text: current);
    var cancelled = false;
    final submitted = await showDialog<String>(
      context: context,
      builder: (ctx) => CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.escape): () {
            cancelled = true;
            Navigator.pop(ctx);
          },
        },
        child: Dialog(
          backgroundColor: context.palette.surfaceElevated,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    title.toUpperCase(),
                    style: AppTypography.mono(context.palette).copyWith(
                      fontSize: 11,
                      letterSpacing: 0.66,
                      color: context.palette.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: c,
                    autofocus: true,
                    minLines: lines > 1 ? 3 : 1,
                    maxLines: lines > 1 ? null : 1,
                    textInputAction: lines > 1
                        ? TextInputAction.newline
                        : TextInputAction.done,
                    onSubmitted: (v) => Navigator.pop(ctx, v),
                    decoration: const InputDecoration(isDense: true),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    if (cancelled) return null;
    // Tocar fuera cierra y guarda lo escrito.
    return submitted ?? c.text;
  }

  Future<void> _edit(
    String title,
    String key,
    String current, {
    int lines = 1,
    void Function(String)? also,
  }) async {
    final raw = await _quickEdit(title, current, lines: lines);
    if (raw == null) return;
    final v = raw.trim();
    if (v == current.trim()) return;
    await widget.onExtras({key: v});
    also?.call(v);
    if (mounted) setState(() {});
  }

  Future<void> _editList(String title, String key, List<String> current) async {
    final raw = await _quickEdit(
      '$title · una línea por elemento',
      current.join('\n'),
      lines: 6,
    );
    if (raw == null) return;
    final items = raw
        .split('\n')
        .map((e) => e.replaceFirst(RegExp(r'^[\s•\-]+'), '').trim())
        .where((e) => e.isNotEmpty)
        .toList();
    await widget.onExtras({key: items});
  }

  Future<void> _saveModel() async {
    await widget.onSaveRef(_model);
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Localización guardada')));
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
        fileName:
            'loc_${DateTime.now().millisecondsSinceEpoch}${p.extension(path).isEmpty ? '.jpg' : p.extension(path)}',
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
    await widget.onSaveRef(_model);
  }

  Future<void> _pastePhoto(ClipboardImagePayload payload) async {
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
    await widget.onSaveRef(_model);
  }

  Future<void> _dropMoodboardPhoto(MoodboardDragPayload drag) async {
    if (!File(drag.imagePath).existsSync()) return;
    final db = ref.read(databaseProvider);
    // Prefer shared moodboard link over copying a disconnected path.
    await MoodboardHelpers.linkMoodboardToSection(
      db: db,
      projectId: widget.projectId,
      payload: drag,
      sectionId: BibleSectionId.location,
      locationName: widget.plan.locationName,
      locationBasePlanId: widget.plan.id,
    );
    final lightCard = await db.getNarrativeCardForLocationLight(
      widget.bibleId,
      widget.plan.id,
    );
    if (lightCard != null && drag.moodboardImageId != null) {
      await db.assignMoodboardImageToCard(
        imageId: drag.moodboardImageId!,
        cardId: lightCard.id,
        sectionId: BibleSectionId.lighting,
      );
    }
    if (!_model.referenceImages.contains(drag.imagePath)) {
      _model.referenceImages.add(drag.imagePath);
    }
    setState(() {});
    await widget.onSaveRef(_model);
  }

  Future<void> _syncLightingNoteToCard(String note) async {
    final db = ref.read(databaseProvider);
    await LightingNarrativeCardsService.ensureSeeded(
      db: db,
      bibleId: widget.bibleId,
      projectId: widget.projectId,
    );
    await LightingNarrativeCardsService.syncLocationNoteToCard(
      db: db,
      bibleId: widget.bibleId,
      locationBasePlanId: widget.plan.id,
      lightingNote: note.trim().isEmpty ? null : note.trim(),
    );
  }

  Future<void> _openMaps() async {
    final url = _s('mapsUrl');
    final coords = _coordsText();
    final uri = url.isNotEmpty
        ? Uri.tryParse(url)
        : coords.isNotEmpty
        ? Uri.parse(
            'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(coords)}',
          )
        : Uri.parse(
            'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(widget.plan.locationName)}',
          );
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  /// Coordenadas de la localización si está ubicada; si no, las escritas
  /// a mano en la biblia.
  String _coordsText() {
    final site = widget.site;
    if (site?.latitude != null && site?.longitude != null) {
      return formatCoordinates(site!.latitude!, site.longitude!);
    }
    return _s('coords');
  }

  Future<void> _locateSite() async {
    final site = widget.site;
    if (site == null) {
      await _edit('Coordenadas', 'coords', _s('coords'));
      return;
    }
    final typed = _s('coords');
    await pickSitePlace(
      context,
      ref,
      site,
      initialQuery: site.latitude == null && parseCoordinates(typed) != null
          ? typed
          : null,
    );
  }

  /// Rellena los campos de sol con lo calculado para un día en la
  /// ubicación de la localización. Siguen siendo editables a mano.
  Future<void> _fillSunFromPlace() async {
    final site = widget.site;
    final lat = site?.latitude;
    final lon = site?.longitude;
    if (lat == null || lon == null) return;
    final now = DateTime.now();
    final day = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 5),
      helpText: '¿Para qué día calculo el sol?',
    );
    if (day == null) return;
    final sun = SunDaySummary.of(day, lat, lon);
    await widget.onExtras({
      'sunrise': sun.sunrise,
      'sunset': sun.sunset,
      'daylightWindow': sun.daylight,
      'blueHour': sun.blueEvening,
      'goldenHour': sun.goldenEvening,
    });
  }

  Future<void> _openEarth() async {
    final url = _s('earthUrl');
    final coords = _coordsText();
    final uri = url.isNotEmpty
        ? Uri.tryParse(url)
        : coords.isNotEmpty
        ? Uri.parse(
            'https://earth.google.com/web/search/${Uri.encodeComponent(coords)}',
          )
        : Uri.parse(
            'https://earth.google.com/web/search/${Uri.encodeComponent(widget.plan.locationName)}',
          );
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final palette = widget.palette;
    final locLabel = _s(
      'locLabel',
      (widget.siteName ?? widget.plan.locationName).toUpperCase(),
    );
    final intExt = _s('intExt', '');
    final azimuth = (x['azimuth'] as num?)?.toDouble() ?? 0;
    final sunrise = _s('sunrise', '');
    final sunriseAz = _s('sunriseAz', '');
    final sunset = _s('sunset', '');
    final sunsetAz = _s('sunsetAz', '');
    final daylight = _s('daylightWindow', _model.availableLightHours ?? '');
    final blueHour = _s('blueHour', '');
    final goldenHour = _s('goldenHour', '');
    final maxElev = _s('maxElevation', '');
    final shadow = _s('shadowRatio', '');
    final elevation = _s('elevation', '');

    final contrast = _s('contrastRatio', '');
    final quality = _s('lightQuality', '');
    final bounce = _s('bouncePotential', '');
    final siteLightNote = _s('siteLightNote', _model.lightingNote ?? '');

    final weather = _s('weather', '');
    final humidity = _s('humidity', '');
    final sky = _s('skyQuality', '');
    final wind = _s('wind', '');

    final psychology = _s('spatialPsychology', _model.stagingNote ?? '');
    final strategy = _s('strategy', '');
    final narrativeGeo = _s('narrativeGeography', '');
    final textureMat = _s('textureMateriality', '');
    final soundscape = _s('soundscape', '');
    final practicals = _s('practicalsDetail', _model.existingPracticals ?? '');

    final gear = _list('extraGear', const []);
    final critical = _list('criticalPoints', const []);
    final colors = _paletteColors();

    final heroPath = _model.referenceImages.isNotEmpty
        ? _model.referenceImages.first
        : widget.plan.imagePath;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Glass(
          padding: const EdgeInsets.all(4),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: BibleTargetZone(
              hint: 'Clic aquí y ⌘V para pegar la foto principal',
              minHeight: 0,
              onPaste: _pastePhoto,
              onMoodboardDropped: _dropMoodboardPhoto,
              child: SizedBox(
                height: 320,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (heroPath != null &&
                        heroPath.isNotEmpty &&
                        File(heroPath).existsSync())
                      Image.file(File(heroPath), fit: BoxFit.cover)
                    else
                      StreamBuilder<List<MoodboardImage>>(
                        stream: ref
                            .watch(databaseProvider)
                            .watchMoodboardImagesForSection(
                              widget.projectId,
                              BibleSectionId.location,
                            ),
                        builder: (context, snap) {
                          final imgs = snap.data ?? [];
                          if (imgs.isNotEmpty &&
                              File(imgs.first.imagePath).existsSync()) {
                            return Image.file(
                              File(imgs.first.imagePath),
                              fit: BoxFit.cover,
                            );
                          }
                          return ColoredBox(
                            color: palette.surfaceOverlay,
                            child: Center(
                              child: TextButton.icon(
                                onPressed: _addPhoto,
                                icon: Icon(
                                  Icons.add_photo_alternate_outlined,
                                  color: palette.accent,
                                ),
                                label: Text(
                                  'Añadir hero',
                                  style: TextStyle(color: palette.accent),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    Positioned(
                      top: 8,
                      left: 8,
                      child: IgnorePointer(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.45),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '⌘V',
                            style: AppTypography.mono(
                              palette,
                            ).copyWith(fontSize: 10, color: Colors.white70),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 14,
                      right: 14,
                      child: _Glass(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        child: InkWell(
                          onTap: _locateSite,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              if (widget.site?.placeLabel != null)
                                Text(
                                  widget.site!.placeLabel!,
                                  style: AppTypography.mono(
                                    palette,
                                  ).copyWith(fontSize: 11, color: Colors.white),
                                ),
                              Text(
                                _coordsText().isEmpty
                                    ? 'Ubicar en el mapa'
                                    : _coordsText(),
                                style: AppTypography.mono(
                                  palette,
                                ).copyWith(fontSize: 11, color: Colors.white),
                              ),
                              InkWell(
                                onTap: () =>
                                    _edit('Elevación', 'elevation', elevation),
                                child: Text(
                                  elevation.isEmpty
                                      ? 'Añadir elevación'
                                      : elevation,
                                  style: AppTypography.mono(palette).copyWith(
                                    fontSize: 10,
                                    color: palette.textTertiary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 16,
                      bottom: 16,
                      child: Row(
                        children: [
                          _Pill(
                            icon: Icons.wb_sunny_outlined,
                            label: intExt.isEmpty ? 'INT / EXT' : intExt,
                            palette: palette,
                            onTap: () => _edit('INT/EXT', 'intExt', intExt),
                          ),
                          const SizedBox(width: 8),
                          _Pill(
                            label: 'LOC: $locLabel',
                            palette: palette,
                            onTap: () =>
                                _edit('Nombre del lugar', 'locLabel', locLabel),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, c) {
            final wide = c.maxWidth >= 960;
            final left = Column(
              children: [
                _Glass(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _CardHead(
                        icon: Icons.light_mode_outlined,
                        label: 'Luz del sitio',
                        palette: palette,
                      ),
                      const SizedBox(height: 14),
                      _Kv(
                        label: 'Contraste',
                        value: contrast,
                        onTap: () =>
                            _edit('Contraste', 'contrastRatio', contrast),
                        palette: palette,
                      ),
                      _Kv(
                        label: 'Calidad de la luz',
                        value: quality,
                        onTap: () =>
                            _edit('Calidad de la luz', 'lightQuality', quality),
                        palette: palette,
                      ),
                      _Kv(
                        label: 'Rebote del lugar',
                        value: bounce,
                        onTap: () => _edit(
                          'Rebote del lugar',
                          'bouncePotential',
                          bounce,
                        ),
                        palette: palette,
                      ),
                      const SizedBox(height: 10),
                      InkWell(
                        onTap: () => _edit(
                          'Luz del sitio',
                          'siteLightNote',
                          siteLightNote,
                          lines: 4,
                          also: (v) {
                            _model.lightingNote = v;
                            widget.onSaveRef(_model);
                            _syncLightingNoteToCard(v);
                          },
                        ),
                        child: Text(
                          siteLightNote.isEmpty
                              ? 'Toca para nota de luz del sitio…'
                              : siteLightNote,
                          style: AppTypography.mono(palette).copyWith(
                            fontSize: 11,
                            height: 1.45,
                            color: siteLightNote.isEmpty
                                ? palette.textTertiary
                                : palette.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _LightingIdeaFromBible(
                  projectId: widget.projectId,
                  bibleId: widget.bibleId,
                  planId: widget.plan.id,
                  lightingNote: _model.lightingNote ?? siteLightNote,
                  palette: palette,
                ),
                const SizedBox(height: 16),
                _SolarCard(
                  azimuth: azimuth,
                  sunrise: sunrise,
                  sunriseAz: sunriseAz,
                  sunset: sunset,
                  sunsetAz: sunsetAz,
                  daylight: daylight,
                  blueHour: blueHour,
                  goldenHour: goldenHour,
                  maxElev: maxElev,
                  shadow: shadow,
                  solarNote: _model.solarOrientation ?? '',
                  palette: palette,
                  onCalculate: widget.site?.latitude != null
                      ? _fillSunFromPlace
                      : null,
                  onEditAzimuth: () async {
                    final ctrl = TextEditingController(text: '$azimuth');
                    final v = await showDialog<String>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Acimut (°)'),
                        content: TextField(
                          controller: ctrl,
                          keyboardType: TextInputType.number,
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('Cancelar'),
                          ),
                          FilledButton(
                            onPressed: () =>
                                Navigator.pop(ctx, ctrl.text.trim()),
                            child: const Text('Guardar'),
                          ),
                        ],
                      ),
                    );
                    if (v == null) return;
                    final n = double.tryParse(v);
                    if (n != null) await widget.onExtras({'azimuth': n});
                  },
                  onEditField: (key, title, val) => _edit(title, key, val),
                  onEditSolarNote: () async {
                    final ctrl = TextEditingController(
                      text: _model.solarOrientation ?? '',
                    );
                    final v = await showDialog<String>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Nota solar'),
                        content: TextField(controller: ctrl, maxLines: 3),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('Cancelar'),
                          ),
                          FilledButton(
                            onPressed: () =>
                                Navigator.pop(ctx, ctrl.text.trim()),
                            child: const Text('Guardar'),
                          ),
                        ],
                      ),
                    );
                    if (v == null) return;
                    _model.solarOrientation = v;
                    _model.availableLightHours = daylight;
                    await widget.onSaveRef(_model);
                    setState(() {});
                  },
                ),
                const SizedBox(height: 16),
                _Glass(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _CardHead(
                        icon: Icons.cloud_outlined,
                        label: 'Condiciones atmosféricas',
                        palette: palette,
                      ),
                      const SizedBox(height: 12),
                      _Kv(
                        label: 'Tiempo',
                        value: weather,
                        onTap: () => _edit('Tiempo', 'weather', weather),
                        palette: palette,
                      ),
                      _Kv(
                        label: 'Humedad y bruma',
                        value: humidity,
                        onTap: () =>
                            _edit('Humedad y bruma', 'humidity', humidity),
                        palette: palette,
                      ),
                      _Kv(
                        label: 'Cielo',
                        value: sky,
                        onTap: () => _edit('Cielo', 'skyQuality', sky),
                        palette: palette,
                        accent: true,
                      ),
                      _Kv(
                        label: 'Viento',
                        value: wind,
                        onTap: () => _edit('Viento', 'wind', wind),
                        palette: palette,
                      ),
                    ],
                  ),
                ),
              ],
            );

            final right = Column(
              children: [
                _NarrativeStagingCard(
                  psychology: psychology,
                  strategy: strategy,
                  narrativeGeo: narrativeGeo,
                  textureMat: textureMat,
                  soundscape: soundscape,
                  gear: gear,
                  critical: critical,
                  palette: palette,
                  onEditPsychology: () => _edit(
                    'Psicología del espacio',
                    'spatialPsychology',
                    psychology,
                    lines: 5,
                    also: (v) {
                      _model.stagingNote = v;
                      widget.onSaveRef(_model);
                    },
                  ),
                  onEditStrategy: () =>
                      _edit('Estrategia', 'strategy', strategy, lines: 5),
                  onEditGeo: () => _edit(
                    'Geografía narrativa',
                    'narrativeGeography',
                    narrativeGeo,
                    lines: 4,
                  ),
                  onEditTexture: () => _edit(
                    'Textura',
                    'textureMateriality',
                    textureMat,
                    lines: 4,
                  ),
                  onEditSound: () => _edit(
                    'Paisaje sonoro',
                    'soundscape',
                    soundscape,
                    lines: 3,
                  ),
                  onEditGear: () =>
                      _editList('Equipo extra', 'extraGear', gear),
                  onEditCritical: () =>
                      _editList('Puntos críticos', 'criticalPoints', critical),
                ),
                const SizedBox(height: 16),
                _Glass(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _CardHead(
                        icon: Icons.lightbulb_outline,
                        label: 'Luces del propio lugar',
                        palette: palette,
                      ),
                      const SizedBox(height: 12),
                      InkWell(
                        onTap: () => _edit(
                          'Prácticas',
                          'practicalsDetail',
                          practicals,
                          lines: 5,
                          also: (v) {
                            _model.existingPracticals = v;
                            widget.onSaveRef(_model);
                          },
                        ),
                        child: Text(
                          practicals.isEmpty
                              ? 'Fluorescentes, emergencia, vapor de sodio…'
                              : practicals,
                          style: AppTypography.bodyMedium(palette).copyWith(
                            color: practicals.isEmpty
                                ? palette.textTertiary
                                : palette.textSecondary,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _PaletteCard(
                  colors: colors,
                  colorNote: _model.colorNote ?? '',
                  palette: palette,
                  onEditColors: () async {
                    final updated = await BiblePaletteEditorSheet.show(
                      context,
                      title: 'Colores base del lugar',
                      initialColors: colors,
                    );
                    if (updated == null) return;
                    await widget.onExtras({'palette': updated});
                    _model.colorNote = updated.isEmpty
                        ? (_model.colorNote ?? '')
                        : updated.join(' · ');
                    await widget.onSaveRef(_model);
                    setState(() {});
                  },
                  onEditNote: () async {
                    final ctrl = TextEditingController(
                      text: _model.colorNote ?? '',
                    );
                    final v = await showDialog<String>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Nota de color'),
                        content: TextField(controller: ctrl, maxLines: 3),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('Cancelar'),
                          ),
                          FilledButton(
                            onPressed: () =>
                                Navigator.pop(ctx, ctrl.text.trim()),
                            child: const Text('Guardar'),
                          ),
                        ],
                      ),
                    );
                    if (v == null) return;
                    _model.colorNote = v;
                    await widget.onSaveRef(_model);
                    setState(() {});
                  },
                ),
                const SizedBox(height: 16),
                _MapsCard(
                  palette: palette,
                  onEarth: _openEarth,
                  onMaps: _openMaps,
                  onEditLinks: () async {
                    await _edit('URL Google Maps', 'mapsUrl', _s('mapsUrl'));
                    await _edit('URL Google Earth', 'earthUrl', _s('earthUrl'));
                  },
                ),
                const SizedBox(height: 16),
                _RefsGallery(
                  images: _model.referenceImages,
                  projectId: widget.projectId,
                  locationName: _model.locationName,
                  planId: widget.plan.id,
                  palette: palette,
                  onAdd: _addPhoto,
                  onPaste: _pastePhoto,
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton(
                    onPressed: _saveModel,
                    child: const Text('Guardar localización'),
                  ),
                ),
              ],
            );

            if (wide) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 4, child: left),
                  const SizedBox(width: 16),
                  Expanded(flex: 8, child: right),
                ],
              );
            }
            return Column(children: [left, const SizedBox(height: 16), right]);
          },
        ),
      ],
    );
  }
}

class _SolarCard extends StatelessWidget {
  final double azimuth;
  final String sunrise;
  final String sunriseAz;
  final String sunset;
  final String sunsetAz;
  final String daylight;
  final String blueHour;
  final String goldenHour;
  final String maxElev;
  final String shadow;
  final String solarNote;
  final AppPalette palette;
  final VoidCallback onEditAzimuth;
  final void Function(String key, String title, String val) onEditField;
  final VoidCallback onEditSolarNote;

  /// Nulo si la localización no está ubicada en el mapa.
  final VoidCallback? onCalculate;

  const _SolarCard({
    required this.azimuth,
    required this.sunrise,
    required this.sunriseAz,
    required this.sunset,
    required this.sunsetAz,
    required this.daylight,
    required this.blueHour,
    required this.goldenHour,
    required this.maxElev,
    required this.shadow,
    required this.solarNote,
    required this.palette,
    required this.onEditAzimuth,
    required this.onEditField,
    required this.onEditSolarNote,
    this.onCalculate,
  });

  @override
  Widget build(BuildContext context) {
    return _Glass(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardHead(
            icon: Icons.explore_outlined,
            label: 'Orientación Solar',
            palette: palette,
          ),
          if (onCalculate != null)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: onCalculate,
                icon: const Icon(Icons.wb_twilight_outlined, size: 16),
                label: const Text('Calcular con la ubicación'),
              ),
            ),
          const SizedBox(height: 8),
          InkWell(
            onTap: onEditSolarNote,
            child: Text(
              solarNote.isEmpty
                  ? 'Análisis de trayectoria solar y proyección de sombras…'
                  : solarNote,
              style: AppTypography.mono(palette).copyWith(
                fontSize: 11,
                color: palette.textTertiary,
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: InkWell(
              onTap: onEditAzimuth,
              child: SizedBox(
                width: 160,
                height: 160,
                child: CustomPaint(
                  painter: _AzimuthDialPainter(
                    azimuth: azimuth,
                    accent: palette.accent,
                  ),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${azimuth.round()}°',
                          style: AppTypography.mono(palette).copyWith(
                            fontSize: 22,
                            fontWeight: FontWeight.w600,
                            color: palette.accent,
                          ),
                        ),
                        Text(
                          'ACIMUT',
                          style: AppTypography.mono(
                            palette,
                          ).copyWith(fontSize: 10, color: palette.textTertiary),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _MiniStat(
                  label: 'Amanecer',
                  value: sunrise,
                  sub: sunriseAz.isEmpty ? null : 'Acimut $sunriseAz',
                  palette: palette,
                  onTap: () {
                    onEditField('sunrise', 'Amanecer', sunrise);
                    onEditField('sunriseAz', 'Acimut del amanecer', sunriseAz);
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MiniStat(
                  label: 'Atardecer',
                  value: sunset,
                  sub: sunsetAz.isEmpty ? null : 'Acimut $sunsetAz',
                  palette: palette,
                  onTap: () {
                    onEditField('sunset', 'Atardecer', sunset);
                    onEditField('sunsetAz', 'Acimut del atardecer', sunsetAz);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _MiniStat(
            label: 'Ventana de luz útil',
            value: daylight,
            sub: null,
            palette: palette,
            accentValue: true,
            onTap: () =>
                onEditField('daylightWindow', 'Ventana de luz', daylight),
          ),
          const SizedBox(height: 8),
          _Kv(
            label: 'Hora azul',
            value: blueHour,
            onTap: () => onEditField('blueHour', 'Hora azul', blueHour),
            palette: palette,
          ),
          _Kv(
            label: 'Hora dorada',
            value: goldenHour,
            onTap: () => onEditField('goldenHour', 'Hora dorada', goldenHour),
            palette: palette,
          ),
          _Kv(
            label: 'Altura máxima del sol',
            value: maxElev,
            onTap: () =>
                onEditField('maxElevation', 'Altura máxima del sol', maxElev),
            palette: palette,
          ),
          _Kv(
            label: 'Largo de sombra a mediodía',
            value: shadow,
            onTap: () => onEditField(
              'shadowRatio',
              'Largo de sombra a mediodía',
              shadow,
            ),
            palette: palette,
          ),
        ],
      ),
    );
  }
}

class _NarrativeStagingCard extends StatelessWidget {
  final String psychology;
  final String strategy;
  final String narrativeGeo;
  final String textureMat;
  final String soundscape;
  final List<String> gear;
  final List<String> critical;
  final AppPalette palette;
  final VoidCallback onEditPsychology;
  final VoidCallback onEditStrategy;
  final VoidCallback onEditGeo;
  final VoidCallback onEditTexture;
  final VoidCallback onEditSound;
  final VoidCallback onEditGear;
  final VoidCallback onEditCritical;

  const _NarrativeStagingCard({
    required this.psychology,
    required this.strategy,
    required this.narrativeGeo,
    required this.textureMat,
    required this.soundscape,
    required this.gear,
    required this.critical,
    required this.palette,
    required this.onEditPsychology,
    required this.onEditStrategy,
    required this.onEditGeo,
    required this.onEditTexture,
    required this.onEditSound,
    required this.onEditGear,
    required this.onEditCritical,
  });

  @override
  Widget build(BuildContext context) {
    return _Glass(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardHead(
            icon: Icons.psychology_outlined,
            label: 'Refuerzo narrativo y puesta en escena',
            palette: palette,
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, c) {
              final wide = c.maxWidth >= 520;
              final a = _NarrativeBlock(
                title: 'Psicología del espacio',
                body: psychology,
                hint: 'Qué le hace el lugar al personaje…',
                onTap: onEditPsychology,
                palette: palette,
              );
              final b = _NarrativeBlock(
                title: 'Estrategia general',
                body: strategy,
                hint: 'Cómo se va a iluminar y a mover la cámara aquí…',
                onTap: onEditStrategy,
                palette: palette,
              );
              if (wide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: a),
                    const SizedBox(width: 20),
                    Expanded(child: b),
                  ],
                );
              }
              return Column(children: [a, const SizedBox(height: 16), b]);
            },
          ),
          const SizedBox(height: 16),
          _NarrativeBlock(
            title: 'Geografía narrativa',
            body: narrativeGeo,
            hint: 'Cómo el espacio condiciona los movimientos de los actores…',
            onTap: onEditGeo,
            palette: palette,
          ),
          const SizedBox(height: 12),
          _NarrativeBlock(
            title: 'Textura y materiales',
            body: textureMat,
            hint: 'Hormigón, metal, cuánto absorbe o devuelve la luz…',
            onTap: onEditTexture,
            palette: palette,
          ),
          const SizedBox(height: 12),
          _NarrativeBlock(
            title: 'Paisaje sonoro',
            body: soundscape,
            hint: 'Reverberación, ritmo de cámara…',
            onTap: onEditSound,
            palette: palette,
          ),
          const SizedBox(height: 16),
          Divider(height: 1, color: Colors.white.withValues(alpha: 0.06)),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: InkWell(
                  onTap: onEditGear,
                  child: Container(
                    padding: const EdgeInsets.only(left: 10),
                    decoration: BoxDecoration(
                      border: Border(
                        left: BorderSide(
                          color: palette.accent.withValues(alpha: 0.5),
                          width: 2,
                        ),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'EQUIPO EXTRA',
                          style: AppTypography.label(palette).copyWith(
                            fontSize: 10,
                            letterSpacing: 1.2,
                            color: palette.textTertiary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        for (final g in gear)
                          Text(
                            '• $g',
                            style: AppTypography.mono(
                              palette,
                            ).copyWith(fontSize: 11),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: InkWell(
                  onTap: onEditCritical,
                  child: Container(
                    padding: const EdgeInsets.only(left: 10),
                    decoration: BoxDecoration(
                      border: Border(
                        left: BorderSide(
                          color: palette.error.withValues(alpha: 0.5),
                          width: 2,
                        ),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'PUNTOS CRÍTICOS',
                          style: AppTypography.label(palette).copyWith(
                            fontSize: 10,
                            letterSpacing: 1.2,
                            color: palette.textTertiary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        for (final g in critical)
                          Text(
                            '• $g',
                            style: AppTypography.mono(
                              palette,
                            ).copyWith(fontSize: 11),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PaletteCard extends StatelessWidget {
  final List<String> colors;
  final String colorNote;
  final AppPalette palette;
  final VoidCallback onEditColors;
  final VoidCallback onEditNote;

  const _PaletteCard({
    required this.colors,
    required this.colorNote,
    required this.palette,
    required this.onEditColors,
    required this.onEditNote,
  });

  Color? _parse(String hex) {
    var h = hex.trim();
    if (h.startsWith('#')) h = h.substring(1);
    if (h.length != 6) return null;
    final v = int.tryParse(h, radix: 16);
    if (v == null) return null;
    return Color(0xFF000000 | v);
  }

  @override
  Widget build(BuildContext context) {
    return _Glass(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardHead(
            icon: Icons.palette_outlined,
            label: 'Colores base del lugar',
            palette: palette,
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: onEditColors,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                height: 72,
                child: Row(
                  children: [
                    for (final hex in colors)
                      Expanded(
                        child: ColoredBox(
                          color: _parse(hex) ?? Colors.grey,
                          child: Align(
                            alignment: Alignment.bottomLeft,
                            child: Padding(
                              padding: const EdgeInsets.all(6),
                              child: Text(
                                (() {
                                  final c = _parse(hex);
                                  if (c == null) return hex;
                                  for (final s in kBibleLookSwatches) {
                                    final dr = (c.r - s.color.r) * 255;
                                    final dg = (c.g - s.color.g) * 255;
                                    final db = (c.b - s.color.b) * 255;
                                    if (dr * dr + dg * dg + db * db < 80) {
                                      return s.name;
                                    }
                                  }
                                  return 'Color';
                                })(),
                                style: AppTypography.caption(palette).copyWith(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                  shadows: const [
                                    Shadow(
                                      blurRadius: 4,
                                      color: Colors.black54,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          InkWell(
            onTap: onEditNote,
            child: Text(
              colorNote.isEmpty ? 'Nota de paleta…' : colorNote,
              style: AppTypography.mono(
                palette,
              ).copyWith(fontSize: 11, color: palette.textTertiary),
            ),
          ),
        ],
      ),
    );
  }
}

class _MapsCard extends StatelessWidget {
  final AppPalette palette;
  final VoidCallback onEarth;
  final VoidCallback onMaps;
  final VoidCallback onEditLinks;

  const _MapsCard({
    required this.palette,
    required this.onEarth,
    required this.onMaps,
    required this.onEditLinks,
  });

  @override
  Widget build(BuildContext context) {
    return _Glass(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardHead(
            icon: Icons.map_outlined,
            label: 'En el mapa',
            palette: palette,
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: onEditLinks,
            child: Container(
              height: 100,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.link, color: palette.accent, size: 22),
                  const SizedBox(height: 8),
                  Text(
                    'VINCULAR COORDENADAS Y TRAYECTORIA SOLAR',
                    textAlign: TextAlign.center,
                    style: AppTypography.mono(palette).copyWith(
                      fontSize: 10,
                      letterSpacing: 1.1,
                      color: palette.accent,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: onEarth,
                icon: Icon(Icons.open_in_new, size: 14, color: palette.accent),
                label: Text(
                  'Google Earth',
                  style: TextStyle(color: palette.accent, fontSize: 11),
                ),
              ),
              OutlinedButton.icon(
                onPressed: onMaps,
                icon: Icon(Icons.map, size: 14, color: palette.accent),
                label: Text(
                  'Google Maps',
                  style: TextStyle(color: palette.accent, fontSize: 11),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RefsGallery extends StatelessWidget {
  final List<String> images;
  final int projectId;
  final String locationName;
  final int planId;
  final AppPalette palette;
  final VoidCallback onAdd;
  final Future<void> Function(ClipboardImagePayload) onPaste;

  const _RefsGallery({
    required this.images,
    required this.projectId,
    required this.locationName,
    required this.planId,
    required this.palette,
    required this.onAdd,
    required this.onPaste,
  });

  @override
  Widget build(BuildContext context) {
    return _Glass(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _CardHead(
                  icon: Icons.collections_outlined,
                  label: 'Referencias de ángulo',
                  palette: palette,
                ),
              ),
              IconButton(
                onPressed: onAdd,
                icon: Icon(
                  Icons.add_photo_alternate_outlined,
                  color: palette.accent,
                  size: 20,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          BibleTargetZone(
            hint: '⌘V para pegar foto de $locationName',
            minHeight: 100,
            onPaste: onPaste,
            child: images.isEmpty
                ? null
                : SizedBox(
                    height: 120,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.all(8),
                      itemCount: images.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (_, i) {
                        final f = File(images[i]);
                        return ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: f.existsSync()
                              ? Image.file(
                                  f,
                                  width: 160,
                                  height: 120,
                                  fit: BoxFit.cover,
                                )
                              : const SizedBox(width: 160, height: 120),
                        );
                      },
                    ),
                  ),
          ),
          const SizedBox(height: 12),
          Text(
            'Moodboard · $locationName',
            style: AppTypography.label(palette),
          ),
          const SizedBox(height: 8),
          MoodboardStrip.forLocation(
            projectId: projectId,
            locationName: locationName,
            locationBasePlanId: planId,
            showTitle: false,
            showCaptions: true,
            draggable: true,
          ),
        ],
      ),
    );
  }
}

class _Glass extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;

  const _Glass({required this.child, this.padding});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding ?? const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xB31A1A1C),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: child,
    );
  }
}

class _CardHead extends StatelessWidget {
  final IconData icon;
  final String label;
  final AppPalette palette;

  const _CardHead({
    required this.icon,
    required this.label,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: palette.accent),
        const SizedBox(width: 8),
        Text(
          label.toUpperCase(),
          style: AppTypography.label(
            palette,
          ).copyWith(fontSize: 11, letterSpacing: 1.4),
        ),
      ],
    );
  }
}

class _Kv extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback onTap;
  final AppPalette palette;
  final bool accent;

  const _Kv({
    required this.label,
    required this.value,
    required this.onTap,
    required this.palette,
    this.accent = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: AppTypography.mono(
                  palette,
                ).copyWith(fontSize: 12, color: palette.textTertiary),
              ),
            ),
            Flexible(
              child: Text(
                value.isEmpty ? '—' : value,
                textAlign: TextAlign.right,
                style: AppTypography.mono(palette).copyWith(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: accent ? palette.accent : Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final String? sub;
  final AppPalette palette;
  final bool accentValue;
  final VoidCallback onTap;

  const _MiniStat({
    required this.label,
    required this.value,
    required this.sub,
    required this.palette,
    required this.onTap,
    this.accentValue = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0x802A2A2C),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label.toUpperCase(),
              style: AppTypography.label(
                palette,
              ).copyWith(fontSize: 10, color: palette.textTertiary),
            ),
            const SizedBox(height: 4),
            Text(
              value.isEmpty ? '—' : value,
              style: AppTypography.mono(palette).copyWith(
                fontSize: 13,
                color: accentValue ? palette.accent : Colors.white,
              ),
            ),
            if (sub != null)
              Text(
                sub!,
                style: AppTypography.mono(palette).copyWith(
                  fontSize: 10,
                  color: palette.accent.withValues(alpha: 0.7),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _NarrativeBlock extends StatelessWidget {
  final String title;
  final String body;
  final String hint;
  final VoidCallback onTap;
  final AppPalette palette;

  const _NarrativeBlock({
    required this.title,
    required this.body,
    required this.hint,
    required this.onTap,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: AppTypography.mono(palette).copyWith(
              fontSize: 11,
              letterSpacing: 1.1,
              color: palette.accent.withValues(alpha: 0.85),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            body.isEmpty ? hint : body,
            style: AppTypography.bodyMedium(palette).copyWith(
              fontSize: 15,
              height: 1.55,
              color: body.isEmpty
                  ? palette.textTertiary
                  : palette.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final AppPalette palette;
  final IconData? icon;
  final VoidCallback onTap;

  const _Pill({
    required this.label,
    required this.palette,
    required this.onTap,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: palette.accent),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: AppTypography.mono(palette).copyWith(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _AzimuthDialPainter extends CustomPainter {
  final double azimuth;
  final Color accent;

  _AzimuthDialPainter({required this.azimuth, required this.accent});

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2 - 6;
    final ring = Paint()
      ..color = Colors.white.withValues(alpha: 0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(c, r, ring);

    final tick = Paint()
      ..color = Colors.white.withValues(alpha: 0.2)
      ..strokeWidth = 1;
    for (var i = 0; i < 12; i++) {
      final a = (i / 12) * math.pi * 2 - math.pi / 2;
      final p1 = Offset(
        c.dx + math.cos(a) * (r - 8),
        c.dy + math.sin(a) * (r - 8),
      );
      final p2 = Offset(c.dx + math.cos(a) * r, c.dy + math.sin(a) * r);
      canvas.drawLine(p1, p2, tick);
    }

    final rad = (azimuth - 90) * math.pi / 180;
    final sun = Offset(
      c.dx + math.cos(rad) * (r - 18),
      c.dy + math.sin(rad) * (r - 18),
    );
    final arm = Paint()
      ..color = accent
      ..strokeWidth = 2;
    canvas.drawLine(c, sun, arm);
    canvas.drawCircle(sun, 7, Paint()..color = accent);
  }

  @override
  bool shouldRepaint(covariant _AzimuthDialPainter oldDelegate) =>
      oldDelegate.azimuth != azimuth || oldDelegate.accent != accent;
}

/// Pincelada de luz sincronizada desde Iluminación + CTA de drill-down.
class _LightingIdeaFromBible extends ConsumerWidget {
  final int projectId;
  final int bibleId;
  final int planId;
  final String lightingNote;
  final AppPalette palette;

  const _LightingIdeaFromBible({
    required this.projectId,
    required this.bibleId,
    required this.planId,
    required this.lightingNote,
    required this.palette,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(databaseProvider);

    return FutureBuilder<VisualBibleNarrativeCard?>(
      future: () async {
        await LightingNarrativeCardsService.ensureSeeded(
          db: db,
          bibleId: bibleId,
          projectId: projectId,
        );
        return db.getNarrativeCardForLocationLight(bibleId, planId);
      }(),
      builder: (context, snap) {
        final card = snap.data;
        final summary = card != null
            ? NarrativeCardModel.fromRow(card).summary
            : null;
        final text = (summary?.isNotEmpty == true)
            ? summary!
            : (lightingNote.isNotEmpty
                  ? lightingNote
                  : 'Sin idea de luz aún — ábrela en Iluminación.');

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xB31A1A1C),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.wb_sunny_outlined,
                    size: 16,
                    color: palette.accent,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'IDEA DE LUZ (DESDE ILUMINACIÓN)',
                      style: AppTypography.mono(palette).copyWith(
                        fontSize: 11,
                        letterSpacing: 1.1,
                        color: palette.textTertiary,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () async {
                      if (card != null) {
                        await NarrativeCardDetailPage.open(
                          context,
                          projectId: projectId,
                          bibleId: bibleId,
                          cardId: card.id,
                        );
                      } else {
                        BibleNavigationScope.goToSection(
                          context,
                          BibleSectionId.lighting,
                          planId: planId,
                        );
                      }
                    },
                    child: Text(
                      'Abrir en Iluminación',
                      style: TextStyle(color: palette.accent, fontSize: 12),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                text,
                style: AppTypography.bodyMedium(
                  palette,
                ).copyWith(color: palette.textSecondary, height: 1.45),
              ),
              if (card != null) ...[
                const SizedBox(height: 12),
                SizedBox(
                  height: 72,
                  child: StreamBuilder<List<MoodboardImage>>(
                    stream: db.watchMoodboardImagesForCard(projectId, card.id),
                    builder: (context, imgSnap) {
                      final imgs = imgSnap.data ?? [];
                      if (imgs.isEmpty) return const SizedBox.shrink();
                      return ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: imgs.length.clamp(0, 8),
                        separatorBuilder: (_, __) => const SizedBox(width: 6),
                        itemBuilder: (context, i) {
                          final path = imgs[i].imagePath;
                          if (!File(path).existsSync()) {
                            return const SizedBox(width: 96);
                          }
                          return ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: Image.file(
                              File(path),
                              width: 96,
                              height: 72,
                              fit: BoxFit.cover,
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
