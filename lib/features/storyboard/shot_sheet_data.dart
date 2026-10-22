import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' show Size;

import 'package:drift/drift.dart' show innerJoin;

import '../../core/database/app_database.dart';
import '../../core/utils/pdf_safe_image.dart';
import '../../core/utils/shot_reference_import.dart';
import '../../core/weather/sun_calculator.dart';
import '../../core/weather/weather_models.dart';
import '../../shared/rich_text/script_markup.dart';
import '../camera_plan/plan_data.dart';
import '../camera_plan/plan_thumbnail.dart';
import '../luka_export/unreal_coords.dart';
import 'storyboard_export_helpers.dart';
import 'storyboard_image_palette.dart';

/// Qué imagen representa el plano al exportarlo.
enum ShotImageSource {
  /// La del storyboard (si no tiene, la de referencia).
  storyboard,

  /// La de referencia principal (si no tiene, la del storyboard).
  reference,
}

extension ShotImageSourceX on ShotImageSource {
  String get label => switch (this) {
    ShotImageSource.storyboard => 'Storyboard',
    ShotImageSource.reference => 'Referencia',
  };

  String? pathOf(Shot shot) => switch (this) {
    ShotImageSource.storyboard => storyboardImageOf(shot),
    ShotImageSource.reference => referenceImageOf(shot),
  };
}

/// El plano tiene dos imágenes distintas y merece la pena elegir.
bool shotHasBothImages(Shot shot) =>
    shot.storyboardImagePath != null &&
    shot.referenceImagePath != null &&
    shot.storyboardImagePath != shot.referenceImagePath;

/// El sol del día de rodaje en la localización, ya en hora del lugar.
class ShotSheetSun {
  final SunDayPath path;
  final DateTime date;

  /// Viene de una jornada de rodaje con este plano; si no, es el de hoy.
  final bool fromShootDay;
  final int utcOffsetSeconds;
  final double latitude;
  final double longitude;
  final String? placeLabel;

  const ShotSheetSun({
    required this.path,
    required this.date,
    required this.fromShootDay,
    required this.utcOffsetSeconds,
    required this.latitude,
    required this.longitude,
    this.placeLabel,
  });

  /// Hora del lugar de un instante UTC.
  DateTime local(DateTime utc) =>
      utc.toUtc().add(Duration(seconds: utcOffsetSeconds));

  String hhmm(DateTime? utc) {
    if (utc == null) return '—';
    final t = local(utc);
    return '${t.hour}:${t.minute.toString().padLeft(2, '0')}';
  }

  /// Posiciones a horas en punto del lugar, con el sol fuera.
  List<({int hour, double azimuth, double altitude})> hourly() {
    final out = <({int hour, double azimuth, double altitude})>[];
    for (var h = 0; h < 24; h++) {
      final utc = DateTime.utc(
        date.year,
        date.month,
        date.day,
        h,
      ).subtract(Duration(seconds: utcOffsetSeconds));
      final p = SunCalculator.position(utc, latitude, longitude);
      if (p.altitude > 0) {
        out.add((hour: h, azimuth: p.azimuth, altitude: p.altitude));
      }
    }
    return out;
  }

  /// Duración del día, «12:07».
  String get dayLength {
    final rise = path.times.sunrise;
    final set = path.times.sunset;
    if (rise == null || set == null) return '—';
    final d = set.difference(rise);
    return '${d.inHours}:${(d.inMinutes % 60).toString().padLeft(2, '0')}';
  }
}

/// Todo lo que sale en la hoja de un plano, resuelto de la base de datos.
/// Lo que no se sabe queda nulo: la hoja deja el hueco, no se lo inventa.
class ShotSheetData {
  final String projectName;
  /// Número de la escena con su letra: «13A».
  final String sceneNumber;
  final String sceneTitle;

  /// «INT. SALA - DÍA».
  final String sceneSlug;

  /// Descripción del lugar (set o localización).
  final String? placeDescription;
  final int shotNumber;
  final int shotIndex;
  final int totalShots;

  final Uint8List? imageBytes;
  final List<int> palette;
  final DateTime? capturedAt;

  final String? cameraLabel;
  final String? lensSeriesLabel;
  final double sensorWidthMm;
  final int focalMm;
  final int fovDegrees;

  /// Relación de aspecto de las líneas de encuadre (2.39, 1.85…).
  final double framelineAspect;

  /// Del guion técnico.
  final String? framing;
  final String? lens;
  final String? angle;
  final String? movement;
  final String? action;
  final String? notes;
  final String? stop;

  final Uint8List? planPng;

  /// Hay localización/set elegido aunque la planta esté vacía.
  final bool hasPlanPlace;
  final ShotSheetSun? sun;

  const ShotSheetData({
    required this.projectName,
    required this.sceneNumber,
    required this.sceneTitle,
    required this.sceneSlug,
    required this.shotNumber,
    required this.shotIndex,
    required this.totalShots,
    required this.sensorWidthMm,
    required this.focalMm,
    required this.fovDegrees,
    this.framelineAspect = kFramelineAspect,
    this.placeDescription,
    this.imageBytes,
    this.palette = const [],
    this.capturedAt,
    this.cameraLabel,
    this.lensSeriesLabel,
    this.framing,
    this.lens,
    this.angle,
    this.movement,
    this.action,
    this.notes,
    this.stop,
    this.planPng,
    this.hasPlanPlace = false,
    this.sun,
  });

  /// «24mm : 61°».
  String get lensFovLabel => '${focalMm}mm : $fovDegrees°';

  static Future<ShotSheetData> resolve({
    required AppDatabase db,
    required Project project,
    required Scene scene,
    required Shot shot,
    ShotImageSource imageSource = ShotImageSource.storyboard,
    bool withPlanAndSun = false,
    DateTime? today,
  }) async {
    final shots = await db.getShotsForScene(scene.id);
    shots.sort((a, b) => a.number.compareTo(b.number));
    final index = shots.indexWhere((s) => s.id == shot.id);

    final bible = await db.getVisualBibleForProject(project.id);
    final camera = await db.resolveProjectCamera(project.id);
    final projectLens = await db.resolveProjectLens(project.id);
    final sensor = (camera != null && camera.sensorWidthMm > 0)
        ? camera.sensorWidthMm
        : kDefaultSensorWidthMm;

    final imagePath = imageSource.pathOf(shot);
    final imageBytes = await PdfSafeImage.loadFromPathMaxEdge(imagePath);
    final palette = imageBytes == null
        ? const <int>[]
        : [
            for (final c in await StoryboardImagePalette.extractFromBytes(
              imageBytes,
              swatches: 10,
            ))
              c.toARGB32(),
          ];

    final set = shot.locationBasePlanId ?? scene.locationId;
    final setRow = set != null ? await db.getLocationById(set) : null;
    final siteId = setRow?.siteId ?? scene.locationSiteId;
    final site = siteId != null ? await db.getSiteById(siteId) : null;

    return ShotSheetData(
      projectName: project.name,
      sceneNumber: scene.label,
      sceneTitle: scene.name.trim(),
      sceneSlug: sceneLocationLine(scene),
      placeDescription:
          _plain(setRow?.description) ??
          _plain(site?.description) ??
          _plain(site?.placeLabel),
      shotNumber: shot.number,
      shotIndex: index >= 0 ? index + 1 : shot.number,
      totalShots: shots.isEmpty ? shot.number : shots.length,
      imageBytes: imageBytes,
      palette: palette,
      capturedAt: _fileModified(imagePath),
      cameraLabel: camera == null ? null : _cameraLabel(camera),
      lensSeriesLabel: projectLens == null ? null : _lensSeries(projectLens),
      sensorWidthMm: sensor,
      focalMm: parseFocalLengthMm(shot.lens).round(),
      fovDegrees: horizontalFovDegrees(
        shot.lens,
        sensorWidthMm: sensor,
      ).round(),
      framelineAspect: parseAspectRatio(bible?.aspectRatio) ?? kFramelineAspect,
      framing: _plain(shot.framing),
      lens: _plain(shot.lens),
      angle: _plain(shot.angle),
      movement: _plain(shot.movement),
      action: _plain(shot.action),
      notes: _plain(shot.notes),
      stop: _plain(shot.fStop),
      planPng: withPlanAndSun ? await _planPng(db, project.id, shot) : null,
      hasPlanPlace: set != null,
      sun: withPlanAndSun ? await _sun(db, shot, site, today) : null,
    );
  }

  static String? _plain(String? raw) {
    final text = scriptMarkupToPlain(raw).trim();
    return text.isEmpty ? null : text;
  }

  static String _cameraLabel(Camera cam) {
    final name = '${cam.brand} ${cam.model}'.trim();
    // Solo el primer formato: la lista entera no cabe en la barra.
    final format = cam.recordingFormats?.split(RegExp(r'[,;\n]')).first.trim();
    return format == null || format.isEmpty ? name : '$name $format';
  }

  static String _lensSeries(Lense lens) {
    final series = lens.series?.trim();
    if (series != null && series.isNotEmpty) return series;
    return '${lens.brand} ${lens.model}'.trim();
  }

  static DateTime? _fileModified(String? path) {
    if (path == null) return null;
    try {
      final file = File(path);
      return file.existsSync() ? file.statSync().modified : null;
    } catch (_) {
      return null;
    }
  }

  /// La planta del plano (luz, cámaras, actores y bocetos sobre su set);
  /// si el plano no tiene nada propio, la del set de su escena.
  static Future<Uint8List?> _planPng(
    AppDatabase db,
    int projectId,
    Shot shot,
  ) async {
    try {
      final plans = PlanProjectData(
        sites: await db.watchSitesForProject(projectId).first,
        sets: await db.watchLocationsForProject(projectId).first,
        setups: await db.getLightSetupsForProject(projectId),
        scenes: await db.watchScenesForProject(projectId).first,
        shots: await db.getShotsForProject(projectId),
        elementRows: await db
            .watchCameraPlanElementsForProject(projectId)
            .first,
        drawingRows: await db.watchPlanAnnotationDocuments(projectId).first,
      );
      final own = [...plans.lightOfShot(shot), ...plans.ownOfShot(shot)];
      final base = plans.baseOfShot(shot);
      final drawings = plans.drawingsOfShot(shot);
      if (own.isEmpty && base.isEmpty && drawings.isEmpty) return null;
      return PlanThumbnail.renderPng(
        elements: own,
        inherited: base,
        drawings: drawings,
        focus: plans.zoneOf(plans.set(plans.setIdOfShot(shot))),
        size: const Size(900, 640),
      );
    } catch (_) {
      return null;
    }
  }

  static Future<ShotSheetSun?> _sun(
    AppDatabase db,
    Shot shot,
    LocationSite? site,
    DateTime? today,
  ) async {
    final lat = site?.latitude;
    final lon = site?.longitude;
    if (lat == null || lon == null) return null;

    // La jornada de rodaje en la que está el plano, si la hay.
    final rows = await (db.select(db.shootDocumentBlocks).join([
      innerJoin(
        db.shootDocuments,
        db.shootDocuments.id.equalsExp(db.shootDocumentBlocks.documentId),
      ),
    ])..where(db.shootDocumentBlocks.shotId.equals(shot.id))).get();
    ShootDocument? day;
    for (final row in rows) {
      final doc = row.readTable(db.shootDocuments);
      if (doc.shootDate != null && DateTime.tryParse(doc.shootDate!) != null) {
        day = doc;
        break;
      }
    }
    final now = today ?? DateTime.now();
    final date = day != null
        ? DateTime.parse(day.shootDate!)
        : DateTime(now.year, now.month, now.day);

    var offset = DateTime(
      date.year,
      date.month,
      date.day,
      12,
    ).timeZoneOffset.inSeconds;
    final forecast = WeatherSnapshot.decode(day?.weatherSnapshotJson);
    if (forecast != null && forecast.date == day?.shootDate) {
      offset = forecast.utcOffsetSeconds;
    }

    return ShotSheetSun(
      path: SunCalculator.dayPath(
        year: date.year,
        month: date.month,
        day: date.day,
        latitude: lat,
        longitude: lon,
      ),
      date: date,
      fromShootDay: day != null,
      utcOffsetSeconds: offset,
      latitude: lat,
      longitude: lon,
      placeLabel: site?.placeLabel,
    );
  }
}

/// «2.39:1», «1,85», «16:9» → 2.39, 1.85, 1.78. Nulo si no se entiende.
double? parseAspectRatio(String? raw) {
  if (raw == null) return null;
  final text = raw.replaceAll(',', '.');
  final pair = RegExp(
    r'(\d+(?:\.\d+)?)\s*[:x×/]\s*(\d+(?:\.\d+)?)',
  ).firstMatch(text);
  if (pair != null) {
    final a = double.parse(pair.group(1)!);
    final b = double.parse(pair.group(2)!);
    if (a > 0 && b > 0) return a / b;
  }
  final single = RegExp(r'(\d+(?:\.\d+)?)').firstMatch(text);
  final value = single == null ? null : double.tryParse(single.group(1)!);
  return value != null && value >= 1 && value <= 4 ? value : null;
}
