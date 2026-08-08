import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:drift/drift.dart' as drift;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
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
import '../../../../core/project/project_shoot_context.dart';
import '../../../locations/location_form_sheet.dart';
import '../../../locations/location_site_form_sheet.dart';
import '../bible_navigation_scope.dart';
import '../bible_paste_zone.dart';
import '../moodboard_drag.dart';
import '../bible_visual_color_sheet.dart';
import '../moodboard_strip.dart';

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
  int? _selectedPlanId;

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

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final db = ref.watch(databaseProvider);

    return StreamBuilder<List<LocationSite>>(
      stream: db.watchSitesForProject(widget.projectId),
      builder: (context, siteSnap) {
        final sites = siteSnap.data ?? [];
        return StreamBuilder<List<LocationBasePlan>>(
          stream: db.watchLocationsForProject(widget.projectId),
          builder: (context, locSnap) {
            final allSets = locSnap.data ?? [];
            if (sites.isEmpty && allSets.isEmpty) {
              return Center(
                child: Text(
                  'Las localizaciones se generan al importar el guion.',
                  style: AppTypography.bodyMedium(
                    palette,
                  ).copyWith(color: palette.textTertiary),
                ),
              );
            }

            return StreamBuilder<List<VisualBibleLocationRef>>(
              stream: db.watchLocationRefsForBible(widget.bibleId),
              builder: (context, refSnap) {
                final refsByPlanId = {
                  for (final r in refSnap.data ?? [])
                    if (r.locationBasePlanId != null) r.locationBasePlanId!: r,
                };
                final refsByName = {
                  for (final r in refSnap.data ?? []) r.locationName: r,
                };

                final custom = _getCustom();
                final preferred =
                    _selectedPlanId ??
                    (custom['selectedPlanId'] as num?)?.toInt() ??
                    (allSets.isNotEmpty ? allSets.first.id : null);
                LocationBasePlan? active;
                for (final s in allSets) {
                  if (s.id == preferred) {
                    active = s;
                    break;
                  }
                }
                active ??= allSets.isNotEmpty ? allSets.first : null;

                String? siteName;
                if (active?.siteId != null) {
                  for (final s in sites) {
                    if (s.id == active!.siteId) {
                      siteName = s.name;
                      break;
                    }
                  }
                }

                return ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    _SectionTitle(palette: palette),
                    const SizedBox(height: 12),
                    _LocationHubHeader(
                      palette: palette,
                      projectId: widget.projectId,
                      sites: sites,
                      allSets: allSets,
                      activeSet: active,
                      onSelectSet: (set) {
                        setState(() => _selectedPlanId = set.id);
                        _updateCustom({'selectedPlanId': set.id});
                        ref.read(projectShootContextProvider(widget.projectId).notifier).setActive(
                              siteId: set.siteId,
                              setId: set.id,
                            );
                      },
                      onCreateSite: () async {
                        await showLocationSiteFormSheet(
                          context,
                          projectId: widget.projectId,
                        );
                      },
                      onCreateSet: (siteId) async {
                        await showLocationFormSheet(
                          context,
                          projectId: widget.projectId,
                          siteId: siteId,
                        );
                      },
                    ),
                    const SizedBox(height: 20),
                    if (active != null) ...[
                      Builder(
                        builder: (_) {
                          final refRow =
                              refsByPlanId[active!.id] ??
                              refsByName[active.locationName];
                          final model = refRow != null
                              ? LocationRefModel.fromRow(refRow)
                              : LocationRefModel(
                                  id: 0,
                                  bibleId: widget.bibleId,
                                  locationName: active.locationName,
                                  locationSiteId: active.siteId,
                                  locationBasePlanId: active.id,
                                );
                          model.locationBasePlanId ??= active.id;
                          model.locationSiteId ??= active.siteId;
                          return _FeaturedLocation(
                            projectId: widget.projectId,
                            bibleId: widget.bibleId,
                            plan: active,
                            siteName: siteName,
                            extras: _planExtras(active.id),
                            model: model,
                            palette: palette,
                            onExtras: (patch) =>
                                _updatePlanExtras(active!.id, patch),
                            onSaveRef: (m) =>
                                db.upsertLocationRef(m.toCompanion()),
                          );
                        },
                      ),
                      const SizedBox(height: 28),
                    ],
                    for (final site in sites) ...[
                      _SiteFolderHeader(
                        siteName: site.name,
                        onOpenLocations: () =>
                            BibleNavigationScope.openLocationSet(
                              context,
                              siteId: site.id,
                            ),
                      ),
                      const SizedBox(height: 8),
                    ],
                    if (sites.isEmpty)
                      TextButton.icon(
                        onPressed: () =>
                            BibleNavigationScope.openLocationSet(context),
                        icon: Icon(
                          Icons.open_in_new,
                          size: 16,
                          color: palette.accent,
                        ),
                        label: Text(
                          'Abrir pantalla Localizaciones',
                          style: TextStyle(color: palette.accent),
                        ),
                      ),
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

class _SectionTitle extends StatelessWidget {
  final AppPalette palette;
  const _SectionTitle({required this.palette});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          '10',
          style: AppTypography.displayMedium(palette).copyWith(
            fontSize: 48,
            color: palette.accent.withValues(alpha: 0.45),
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(width: 14),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'LOCALIZACIÓN',
              style: AppTypography.titleMedium(palette).copyWith(
                fontSize: 24,
                letterSpacing: 0.5,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              'NARRATIVE LIGHT & COLOR VARIANT',
              style: AppTypography.mono(palette).copyWith(
                fontSize: 11,
                letterSpacing: 1.2,
                color: palette.accent.withValues(alpha: 0.8),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _FeaturedLocation extends ConsumerStatefulWidget {
  final int projectId;
  final int bibleId;
  final LocationBasePlan plan;
  final String? siteName;
  final Map<String, dynamic> extras;
  final LocationRefModel model;
  final AppPalette palette;
  final Future<void> Function(Map<String, dynamic>) onExtras;
  final Future<void> Function(LocationRefModel) onSaveRef;

  const _FeaturedLocation({
    required this.projectId,
    required this.bibleId,
    required this.plan,
    required this.siteName,
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
    return const ['#1A1C1E', '#3B4045', '#6C7075', '#A58D70', '#CC9B52'];
  }

  Future<void> _edit(
    String title,
    String key,
    String current, {
    int lines = 1,
    void Function(String)? also,
  }) async {
    final c = TextEditingController(text: current);
    final v = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(controller: c, autofocus: true, maxLines: lines),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, c.text.trim()),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    if (v == null) return;
    await widget.onExtras({key: v});
    also?.call(v);
    setState(() {});
  }

  Future<void> _editList(String title, String key, List<String> current) async {
    final c = TextEditingController(text: current.join('\n'));
    final v = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: c,
          autofocus: true,
          maxLines: 6,
          decoration: const InputDecoration(hintText: 'Una línea por ítem'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, c.text),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    if (v == null) return;
    final items = v
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
    _model.referenceImages.add(drag.imagePath);
    setState(() {});
    await widget.onSaveRef(_model);
  }

  Future<void> _openMaps() async {
    final url = _s('mapsUrl');
    final coords = _s('coords');
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

  Future<void> _openEarth() async {
    final url = _s('earthUrl');
    final coords = _s('coords');
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
    final intExt = _s('intExt', 'EXT. DÍA');
    final azimuth = (x['azimuth'] as num?)?.toDouble() ?? 134;
    final sunrise = _s('sunrise', '06:42 AM');
    final sunriseAz = _s('sunriseAz', '72°');
    final sunset = _s('sunset', '19:15 PM');
    final sunsetAz = _s('sunsetAz', '288°');
    final daylight = _s(
      'daylightWindow',
      _model.availableLightHours ?? '12h 33m',
    );
    final blueHour = _s('blueHour', '19:15 – 19:43');
    final goldenHour = _s('goldenHour', '18:20 – 19:15');
    final maxElev = _s('maxElevation', '48° @ 13:00');
    final shadow = _s('shadowRatio', '1 : 1.1');
    final coords = _s('coords', '');
    final elevation = _s('elevation', '');

    final contrast = _s('contrastRatio', '1:8 (High)');
    final quality = _s('lightQuality', 'Hard / Directional');
    final bounce = _s('bouncePotential', 'Low (Dark surfaces)');
    final siteLightNote = _s('siteLightNote', _model.lightingNote ?? '');

    final weather = _s('weather', 'Partly Cloudy, 15°C');
    final humidity = _s('humidity', '65% / Medium Diffusion');
    final sky = _s('skyQuality', 'Bortle Class 5');
    final wind = _s('wind', '12 km/h NW');

    final psychology = _s('spatialPsychology', _model.stagingNote ?? '');
    final strategy = _s('strategy', '');
    final narrativeGeo = _s('narrativeGeography', '');
    final textureMat = _s('textureMateriality', '');
    final soundscape = _s('soundscape', '');
    final practicals = _s('practicalsDetail', _model.existingPracticals ?? '');

    final gear = _list('extraGear', const [
      '2x HMI 18K + Lentes',
      '4x Skypanel S60',
    ]);
    final critical = _list('criticalPoints', const [
      'Reflejos en ventanales',
      'Acceso limitado para generador',
    ]);
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
              hint: 'Clic aquí → ⌘V para pegar foto de hero',
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
                            style: AppTypography.mono(palette).copyWith(
                              fontSize: 10,
                              color: Colors.white70,
                            ),
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
                        onTap: () async {
                          await _edit('Coordenadas', 'coords', coords);
                          await _edit('Elevación', 'elevation', elevation);
                        },
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              coords.isEmpty ? 'Toca para coords' : coords,
                              style: AppTypography.mono(
                                palette,
                              ).copyWith(fontSize: 11, color: Colors.white),
                            ),
                            if (elevation.isNotEmpty)
                              Text(
                                elevation,
                                style: AppTypography.mono(palette).copyWith(
                                  fontSize: 10,
                                  color: palette.textTertiary,
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
                          label: intExt,
                          palette: palette,
                          onTap: () => _edit('INT/EXT', 'intExt', intExt),
                        ),
                        const SizedBox(width: 8),
                        _Pill(
                          label: 'LOC: $locLabel',
                          palette: palette,
                          onTap: () => _edit('Label LOC', 'locLabel', locLabel),
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
                        label: 'Luz del Sitio',
                        palette: palette,
                      ),
                      const SizedBox(height: 14),
                      _Kv(
                        label: 'Contrast Ratio',
                        value: contrast,
                        onTap: () =>
                            _edit('Contrast Ratio', 'contrastRatio', contrast),
                        palette: palette,
                      ),
                      _Kv(
                        label: 'Quality of Light',
                        value: quality,
                        onTap: () => _edit('Quality', 'lightQuality', quality),
                        palette: palette,
                      ),
                      _Kv(
                        label: 'Bounce Potential',
                        value: bounce,
                        onTap: () => _edit('Bounce', 'bouncePotential', bounce),
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
                  onEditAzimuth: () async {
                    final ctrl = TextEditingController(text: '$azimuth');
                    final v = await showDialog<String>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Azimuth (°)'),
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
                        label: 'Condiciones Atmosféricas',
                        palette: palette,
                      ),
                      const SizedBox(height: 12),
                      _Kv(
                        label: 'Weather',
                        value: weather,
                        onTap: () => _edit('Weather', 'weather', weather),
                        palette: palette,
                      ),
                      _Kv(
                        label: 'Humidity / Haze',
                        value: humidity,
                        onTap: () => _edit('Humidity', 'humidity', humidity),
                        palette: palette,
                      ),
                      _Kv(
                        label: 'Sky Quality',
                        value: sky,
                        onTap: () => _edit('Sky', 'skyQuality', sky),
                        palette: palette,
                        accent: true,
                      ),
                      _Kv(
                        label: 'Wind',
                        value: wind,
                        onTap: () => _edit('Wind', 'wind', wind),
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
                    'Spatial Psychology',
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
                        label: 'Practical Light Sources',
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
                          'AZIMUTH',
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
                  label: 'Sunrise',
                  value: sunrise,
                  sub: 'Az: $sunriseAz',
                  palette: palette,
                  onTap: () {
                    onEditField('sunrise', 'Sunrise', sunrise);
                    onEditField('sunriseAz', 'Sunrise Az', sunriseAz);
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MiniStat(
                  label: 'Sunset',
                  value: sunset,
                  sub: 'Az: $sunsetAz',
                  palette: palette,
                  onTap: () {
                    onEditField('sunset', 'Sunset', sunset);
                    onEditField('sunsetAz', 'Sunset Az', sunsetAz);
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
            label: 'Blue Hour',
            value: blueHour,
            onTap: () => onEditField('blueHour', 'Blue Hour', blueHour),
            palette: palette,
          ),
          _Kv(
            label: 'Golden Hour',
            value: goldenHour,
            onTap: () => onEditField('goldenHour', 'Golden Hour', goldenHour),
            palette: palette,
          ),
          _Kv(
            label: 'Max Elevation',
            value: maxElev,
            onTap: () => onEditField('maxElevation', 'Max Elevation', maxElev),
            palette: palette,
          ),
          _Kv(
            label: 'Shadow Ratio (Noon)',
            value: shadow,
            onTap: () => onEditField('shadowRatio', 'Shadow Ratio', shadow),
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
            label: 'Refuerzo Narrativo & Staging',
            palette: palette,
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, c) {
              final wide = c.maxWidth >= 520;
              final a = _NarrativeBlock(
                title: 'Spatial Psychology',
                body: psychology,
                hint: 'Toca para definir…',
                onTap: onEditPsychology,
                palette: palette,
              );
              final b = _NarrativeBlock(
                title: 'Estrategia General',
                body: strategy,
                hint: 'Toca para estrategia de luz/staging…',
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
            title: 'Geografía Narrativa',
            body: narrativeGeo,
            hint: 'Cómo el espacio fuerza el blocking…',
            onTap: onEditGeo,
            palette: palette,
          ),
          const SizedBox(height: 12),
          _NarrativeBlock(
            title: 'Textura y Materialidad',
            body: textureMat,
            hint: 'Concreto, metal, absorción…',
            onTap: onEditTexture,
            palette: palette,
          ),
          const SizedBox(height: 12),
          _NarrativeBlock(
            title: 'Paisaje Sonoro',
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
            label: 'Google Earth Location',
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
                  label: 'Referencias de Ángulo',
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
    return Row(
      children: [
        Icon(Icons.folder_outlined, size: 18, color: palette.accent),
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
                value,
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
              value,
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

class _LocationHubHeader extends StatelessWidget {
  final AppPalette palette;
  final int projectId;
  final List<LocationSite> sites;
  final List<LocationBasePlan> allSets;
  final LocationBasePlan? activeSet;
  final ValueChanged<LocationBasePlan> onSelectSet;
  final VoidCallback onCreateSite;
  final void Function(int siteId) onCreateSet;

  const _LocationHubHeader({
    required this.palette,
    required this.projectId,
    required this.sites,
    required this.allSets,
    required this.activeSet,
    required this.onSelectSet,
    required this.onCreateSite,
    required this.onCreateSet,
  });

  @override
  Widget build(BuildContext context) {
    final orphanSets = allSets.where((s) => s.siteId == null).toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.surfaceElevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'LOCALIZACIONES DEL PROYECTO',
                  style: AppTypography.mono(palette).copyWith(
                    fontSize: 10,
                    letterSpacing: 1.2,
                    color: palette.textSecondary,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: onCreateSite,
                icon: const Icon(Icons.add_location_alt_outlined, size: 16),
                label: const Text('Nueva localización'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (sites.isEmpty && allSets.isEmpty)
            Text(
              'Crea una localización (site) y añade sets de rodaje dentro.',
              style: AppTypography.caption(palette),
            ),
          for (final site in sites) ...[
            Text(
              site.name.toUpperCase(),
              style: AppTypography.label(palette).copyWith(
                fontSize: 11,
                color: palette.success,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final set in allSets.where((s) => s.siteId == site.id))
                  ChoiceChip(
                    label: Text(set.locationName),
                    selected: activeSet?.id == set.id,
                    onSelected: (_) => onSelectSet(set),
                    selectedColor: palette.accent.withValues(alpha: 0.2),
                  ),
                ActionChip(
                  avatar: Icon(Icons.add, size: 16, color: palette.accent),
                  label: const Text('Añadir set'),
                  onPressed: () => onCreateSet(site.id),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
          if (orphanSets.isNotEmpty) ...[
            Text(
              'SETS SIN LOCALIZACIÓN',
              style: AppTypography.label(palette).copyWith(fontSize: 11),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (final set in orphanSets)
                  ChoiceChip(
                    label: Text(set.locationName),
                    selected: activeSet?.id == set.id,
                    onSelected: (_) => onSelectSet(set),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
