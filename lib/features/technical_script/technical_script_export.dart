import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/painting.dart' show Color;

import '../../core/database/app_database.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/pdf_safe_image.dart';
import '../../core/utils/project_color_scheme.dart';
import '../../core/utils/scene_characters.dart';
import '../../core/utils/shot_reference_import.dart';
import '../../core/weather/sun_calculator.dart';
import '../../core/weather/weather_models.dart';
import '../../core/weather/weather_service.dart';
import '../../core/weather/weather_summary.dart';
import '../../shared/technical_script_export/technical_script_doc.dart';
import '../camera_plan/plan_data.dart';
import '../camera_plan/plan_thumbnail.dart';
import 'table/script_sheet_theme.dart';
import 'technical_script_settings.dart';

int _rgb(Color color) => color.toARGB32() & 0xFFFFFF;

/// Monta el guion técnico del proyecto en orden narrativo, tal como se ve en
/// la hoja: mismas columnas, colores e imágenes. Lo que no está en el guion
/// literario va al final.
Future<TechnicalScriptDoc?> buildNarrativeScriptDoc(
  AppDatabase db,
  int projectId,
  TechnicalScriptSettings settings,
) async {
  final project = await db.getProject(projectId);
  if (project == null) return null;

  final scenes = await db.watchScenesForProject(projectId).first;
  final shots = await db.getShotsForProject(projectId);
  final sites = await db.watchSitesForProject(projectId).first;
  final sets = await db.watchLocationsForProject(projectId).first;
  final colors = ProjectColorScheme.resolve(
    sites: sites,
    sets: sets,
    scenes: scenes,
  );
  // El documento es siempre en hoja blanca, se vea como se vea la pantalla.
  final sheet = ScriptSheetTheme.resolve(
    settings.copyWith(view: ScriptView.sheet),
    AppPalette.dark,
  );

  final plans = await _loadPlans(db, projectId, settings);

  final shotsByScene = <int, List<Shot>>{};
  for (final shot in shots) {
    shotsByScene.putIfAbsent(shot.sceneId, () => []).add(shot);
  }

  final sections = <ScriptDocSection>[];
  for (final scene in scenes) {
    final rows = <ScriptDocRow>[];
    for (final shot in shotsByScene[scene.id] ?? const <Shot>[]) {
      rows.add(await _docRow(db, scene, shot, sheet, plans: plans));
    }
    sections.add(
      ScriptDocSection(
        title:
            '${scene.number}. ${scene.locationCanonical}'
            '${scene.offScript ? ' (fuera del guion)' : ''}',
        headerFill: _rgb(sheet.headerFill(colors.sceneColor(scene))),
        rows: rows,
      ),
    );
  }

  return TechnicalScriptDoc(
    title: 'GUION TÉCNICO ${project.name.toUpperCase()}',
    subtitle: project.director == null || project.director!.trim().isEmpty
        ? null
        : 'Dirección: ${project.director}',
    columns: scriptDocColumns(
      hidden: {
        if (!settings.shows(ScriptColumn.fStop)) 'f',
        if (!settings.shows(ScriptColumn.personajes)) 'pers',
        if (!settings.shows(ScriptColumn.duracion)) 'dur',
        if (!settings.shows(ScriptColumn.planta)) 'planta',
      },
    ),
    sections: sections,
  );
}

/// Fila del documento para un plano, con sus colores y su imagen. [order]
/// es su puesto en el orden de rodaje, cuando el documento es una jornada.
Future<ScriptDocRow> _docRow(
  AppDatabase db,
  Scene scene,
  Shot shot,
  ScriptSheetTheme sheet, {
  int? order,
  PlanProjectData? plans,
}) async {
  final cellFills = <String, int>{};
  final raw = shot.cellStylesJson;
  if (raw != null && raw.isNotEmpty) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        for (final entry in decoded.entries) {
          final fill = sheet.rowFill(entry.value as String?);
          if (fill != null) cellFills['${entry.key}'] = _rgb(fill);
        }
      }
    } catch (_) {
      // Un color ilegible no impide exportar.
    }
  }
  final rowFill = sheet.rowFill(shot.notesHighlight);
  // Todas las referencias propias; sin ninguna, la heredada del storyboard.
  final own = referenceImagesOf(
    shot,
    await db.watchReferencesForShot(shot.id).first,
  );
  final images = <Uint8List>[];
  for (final path in own.isEmpty ? [referenceImageOf(shot)] : own) {
    final bytes = await PdfSafeImage.loadFromPathMaxEdge(path, maxEdge: 1200);
    if (bytes != null) images.add(bytes);
  }
  return ScriptDocRow(
    cells: {
      if (order != null) 'orden': '$order',
      'esc': '${scene.number}',
      'plano': '${shot.number}',
      'encuadre': shot.framing ?? '',
      'lens': [
        shot.lens,
        shot.angle,
        shot.movement,
      ].where((v) => v != null && v.trim().isNotEmpty).join('\n'),
      'f': shot.fStop ?? '',
      'pers': decodeSceneCharacters(shot.charactersJson).join(', '),
      'dur': shot.durationSeconds == null ? '' : '${shot.durationSeconds} s',
      'action': shot.action ?? '',
      'notes': shot.notes ?? '',
    },
    fill: rowFill == null ? null : _rgb(rowFill),
    cellFills: cellFills,
    images: images,
    planImages: plans == null ? const [] : await _planImages(plans, shot),
  );
}

/// Las plantas del proyecto, para pintar la columna de planta; nulo si la
/// columna está oculta.
Future<PlanProjectData?> _loadPlans(
  AppDatabase db,
  int projectId,
  TechnicalScriptSettings settings,
) async {
  if (!settings.shows(ScriptColumn.planta)) return null;
  return PlanProjectData(
    sites: await db.watchSitesForProject(projectId).first,
    sets: await db.watchLocationsForProject(projectId).first,
    setups: await db.getLightSetupsForProject(projectId),
    scenes: await db.watchScenesForProject(projectId).first,
    shots: await db.getShotsForProject(projectId),
    elementRows: await db.watchCameraPlanElementsForProject(projectId).first,
    drawingRows: await db.watchPlanAnnotationDocuments(projectId).first,
  );
}

/// Lo que sale en la celda de planta de un plano: su planta dibujada, si
/// tiene algo propio, y después sus bocetos en su orden.
Future<List<Uint8List>> _planImages(PlanProjectData plans, Shot shot) async {
  final images = <Uint8List>[];
  final own = [...plans.lightOfShot(shot), ...plans.ownOfShot(shot)];
  final drawings = plans.drawingsOfShot(shot);
  if (own.isNotEmpty || drawings.isNotEmpty) {
    final png = await PlanThumbnail.renderPng(
      elements: own,
      inherited: plans.baseOfShot(shot),
      drawings: drawings,
      focus: plans.zoneOf(plans.set(plans.setIdOfShot(shot))),
    );
    if (png != null) images.add(png);
  }
  for (final entry in planSketchEntriesOf(shot)) {
    final setupId = planSketchSetupId(entry);
    if (setupId == null) {
      final bytes = await PdfSafeImage.loadFromPathMaxEdge(
        entry,
        maxEdge: 1200,
      );
      if (bytes != null) images.add(bytes);
      continue;
    }
    final setup = plans.setup(setupId);
    if (setup == null) continue;
    final png = await PlanThumbnail.renderPng(
      elements: plans.ownOfSetup(setup),
      inherited: plans.inheritedOfSetup(setup),
      drawings: plans.drawingsOfSetup(setup),
      focus: plans.zoneOf(plans.set(setup.locationBasePlanId)),
    );
    if (png != null) images.add(png);
  }
  return images;
}

const _months = [
  'enero',
  'febrero',
  'marzo',
  'abril',
  'mayo',
  'junio',
  'julio',
  'agosto',
  'septiembre',
  'octubre',
  'noviembre',
  'diciembre',
];
const _weekdays = [
  'lunes',
  'martes',
  'miércoles',
  'jueves',
  'viernes',
  'sábado',
  'domingo',
];

/// «lunes 12 de octubre de 2026» a partir de "2026-10-12".
String formatShootDate(String? iso) {
  final date = iso == null ? null : DateTime.tryParse(iso);
  if (date == null) return iso ?? '';
  return '${_weekdays[date.weekday - 1]} ${date.day} de '
      '${_months[date.month - 1]} de ${date.year}';
}

/// Sol, previsión y resumen de una jornada, con lo que tenga guardado.
({SunTimes? sun, WeatherSnapshot? forecast, List<String> lines})
shootDayWeather(ShootDocument day, LocationSite? site, {DateTime? now}) {
  final date = day.shootDate == null ? null : DateTime.tryParse(day.shootDate!);
  final lat = site?.latitude;
  final lon = site?.longitude;
  final options = WeatherOptions.decode(day.weatherOptionsJson);
  if (date == null || lat == null || lon == null) {
    return (sun: null, forecast: null, lines: const []);
  }
  final sun = SunCalculator.forDate(
    year: date.year,
    month: date.month,
    day: date.day,
    latitude: lat,
    longitude: lon,
  );
  var forecast = WeatherSnapshot.decode(day.weatherSnapshotJson);
  // Una previsión de otra fecha (se cambió el día) ya no vale.
  if (forecast != null && forecast.date != day.shootDate) forecast = null;
  int? hour(String? hhmm) =>
      hhmm == null ? null : int.tryParse(hhmm.split(':').first);
  return (
    sun: sun,
    forecast: forecast,
    lines: weatherSummaryLines(
      options: options,
      sun: sun,
      forecast: forecast,
      // Sin previsión no se conoce la hora del lugar: vale la del equipo.
      utcOffsetSeconds:
          forecast?.utcOffsetSeconds ??
          DateTime(
            date.year,
            date.month,
            date.day,
            12,
          ).timeZoneOffset.inSeconds,
      fromHour: hour(day.shootFromTime),
      toHour: hour(day.shootToTime),
      forecastAvailable: isWithinForecast(date, now ?? DateTime.now()),
    ),
  );
}

/// Monta el guion técnico de una jornada: los planos elegidos en su orden de
/// rodaje, agrupados bajo su escena mientras vayan seguidos, con la fecha,
/// el lugar y la meteorología arriba. El número de plano es el del guion
/// técnico.
Future<TechnicalScriptDoc?> buildShootDayScriptDoc(
  AppDatabase db,
  int documentId,
  TechnicalScriptSettings settings,
) async {
  final day = await db.getShootDocument(documentId);
  if (day == null) return null;
  final project = await db.getProject(day.projectId);
  final blocks = await db.getBlocksForShootDocument(documentId);
  final scenes = await db.watchScenesForProject(day.projectId).first;
  final shots = await db.getShotsForProject(day.projectId);
  final sites = await db.watchSitesForProject(day.projectId).first;
  final sets = await db.watchLocationsForProject(day.projectId).first;
  final colors = ProjectColorScheme.resolve(
    sites: sites,
    sets: sets,
    scenes: scenes,
  );
  final sheet = ScriptSheetTheme.resolve(
    settings.copyWith(view: ScriptView.sheet),
    AppPalette.dark,
  );
  final plans = await _loadPlans(db, day.projectId, settings);
  final sceneById = {for (final s in scenes) s.id: s};
  final shotById = {for (final s in shots) s.id: s};
  final site = sites.where((s) => s.id == day.locationSiteId).firstOrNull;

  final sections = <ScriptDocSection>[];
  Scene? current;
  var rows = <ScriptDocRow>[];
  var order = 0;
  void close() {
    final scene = current;
    if (scene == null || rows.isEmpty) return;
    sections.add(
      ScriptDocSection(
        title: '${scene.number}. ${scene.locationCanonical}',
        headerFill: _rgb(sheet.headerFill(colors.sceneColor(scene))),
        rows: rows,
      ),
    );
    rows = <ScriptDocRow>[];
  }

  for (final block in blocks) {
    final shot = shotById[block.shotId];
    if (shot == null) continue;
    final scene = sceneById[shot.sceneId];
    if (scene == null) continue;
    if (current?.id != scene.id) {
      close();
      current = scene;
    }
    order++;
    rows.add(await _docRow(db, scene, shot, sheet, order: order, plans: plans));
  }
  close();

  final weather = shootDayWeather(day, site);
  final place = [
    if (site != null) site.name,
    if (site?.placeLabel != null && site!.placeLabel!.trim().isNotEmpty)
      site.placeLabel!,
  ].join(' · ');
  final window = day.shootFromTime != null && day.shootToTime != null
      ? 'de ${day.shootFromTime} a ${day.shootToTime}'
      : null;

  return TechnicalScriptDoc(
    title: 'GUION TÉCNICO DE RODAJE · ${(project?.name ?? '').toUpperCase()}',
    subtitle: [
      [
        day.name,
        if (day.shootDate != null) formatShootDate(day.shootDate),
        if (window != null) window,
      ].join(' · '),
      if (place.isNotEmpty) place,
      ...weather.lines,
    ].join('\n'),
    columns: [
      const ScriptDocColumn('orden', 'ORDEN', 760, centered: true),
      ...scriptDocColumns(
        hidden: {
          if (!settings.shows(ScriptColumn.fStop)) 'f',
          if (!settings.shows(ScriptColumn.personajes)) 'pers',
          if (!settings.shows(ScriptColumn.duracion)) 'dur',
          if (!settings.shows(ScriptColumn.planta)) 'planta',
        },
      ),
    ],
    sections: sections,
  );
}

/// Nombre de archivo del guion técnico de un proyecto, sin extensión.
String technicalScriptFileName(String projectName) {
  final clean = projectName.replaceAll(RegExp(r'[^\w\s-]'), '').trim();
  return clean.isEmpty ? 'guion_tecnico' : '${clean}_guion_tecnico';
}
