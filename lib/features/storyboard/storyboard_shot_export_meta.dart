import 'dart:io';

import '../../core/database/app_database.dart';
import '../luka_export/unreal_coords.dart';
import 'storyboard_export_helpers.dart';

/// Metadatos resueltos para exportar un plano (cámara, óptica, orientación).
class StoryboardShotExportMeta {
  final String cameraHeader;
  final String orientationHeader;
  final String lensSeriesHeader;
  final double sensorWidthMm;
  final int shotIndex;
  final int totalShotsInScene;
  final DateTime? capturedAt;

  const StoryboardShotExportMeta({
    required this.cameraHeader,
    required this.orientationHeader,
    required this.lensSeriesHeader,
    required this.sensorWidthMm,
    required this.shotIndex,
    required this.totalShotsInScene,
    this.capturedAt,
  });

  static Future<StoryboardShotExportMeta> resolve({
    required AppDatabase db,
    required Project project,
    required Scene scene,
    required Shot shot,
  }) async {
    try {
      return await _resolve(db, project, scene, shot);
    } catch (_) {
      return StoryboardShotExportMeta(
        cameraHeader: 'Cámara del proyecto',
        orientationHeader: '1° (U) 46° (NE)',
        lensSeriesHeader: _lensSeriesFromShot(shot.lens),
        sensorWidthMm: kDefaultSensorWidthMm,
        shotIndex: shot.number,
        totalShotsInScene: shot.number,
        capturedAt: _fileModified(shot.referenceImagePath),
      );
    }
  }

  static Future<StoryboardShotExportMeta> _resolve(
    AppDatabase db,
    Project project,
    Scene scene,
    Shot shot,
  ) async {
    final shots = await db.getShotsForScene(scene.id);
    shots.sort((a, b) => a.number.compareTo(b.number));
    final index = shots.indexWhere((s) => s.id == shot.id);
    final shotIndex = index >= 0 ? index + 1 : shot.number;
    final total = shots.isEmpty ? shot.number : shots.length;

    var cameraHeader = 'Cámara del proyecto';
    var lensSeriesHeader = _lensSeriesFromShot(shot.lens);
    var sensorWidth = kDefaultSensorWidthMm;

    final equipment = await db.watchProjectEquipment(project.id).first;
    for (final row in equipment) {
      if (row.equipmentType == 'camera') {
        final cameras = await db.watchAllCameras().first;
        final cam = cameras.where((c) => c.id == row.equipmentId).firstOrNull;
        if (cam != null) {
          cameraHeader = _cameraHeaderLabel(cam);
          sensorWidth = cam.sensorWidthMm > 0 ? cam.sensorWidthMm : sensorWidth;
          break;
        }
      }
    }

    for (final row in equipment) {
      if (row.equipmentType == 'lens') {
        final lenses = await db.watchAllLenses().first;
        final lens = lenses.where((l) => l.id == row.equipmentId).firstOrNull;
        if (lens != null) {
          lensSeriesHeader = '${lens.brand} ${lens.model}'.trim();
          break;
        }
      }
    }

    final orientationHeader = _orientationLabel(shot.angle, scene.dayNight);
    final capturedAt = _fileModified(shot.referenceImagePath);

    return StoryboardShotExportMeta(
      cameraHeader: cameraHeader,
      orientationHeader: orientationHeader,
      lensSeriesHeader: lensSeriesHeader,
      sensorWidthMm: sensorWidth,
      shotIndex: shotIndex,
      totalShotsInScene: total,
      capturedAt: capturedAt,
    );
  }

  static String _cameraHeaderLabel(Camera cam) {
    final format = cam.recordingFormats?.trim();
    if (format != null && format.isNotEmpty) {
      return '${cam.brand} ${cam.model} $format'.trim();
    }
    return '${cam.brand} ${cam.model}'.trim();
  }

  static String _lensSeriesFromShot(String? lens) {
    if (lens == null || lens.trim().isEmpty) return 'Óptica';
    final mm = parseFocalLengthMm(lens).round();
    return '${mm}mm';
  }

  static String _orientationLabel(String? angle, String dayNight) {
    final tilt = switch (angle?.toLowerCase()) {
      'picado' => '45°',
      'contrapicado' => '-45°',
      'cenital' => '90°',
      'nadir' => '-90°',
      _ => '1°',
    };
    final bearing = switch (dayNight.toUpperCase()) {
      'NOCHE' || 'NIGHT' => 'N',
      'AMANECER' => 'E',
      'ATARDECER' => 'W',
      _ => 'NE',
    };
    return '$tilt (U) 46° ($bearing)';
  }

  static DateTime? _fileModified(String? path) {
    if (path == null) return null;
    try {
      final file = File(path);
      if (!file.existsSync()) return null;
      return file.statSync().modified;
    } catch (_) {
      return null;
    }
  }
}

extension _FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull {
    final it = iterator;
    return it.moveNext() ? it.current : null;
  }
}
