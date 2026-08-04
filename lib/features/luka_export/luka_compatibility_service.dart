import 'dart:convert';

import '../../core/database/app_database.dart';
import 'luka_manifest_models.dart';
import 'luka_manifest_service.dart';

enum LukaCompatLevel { full, partial, manualOnly, none }

class LukaCompatReport {
  final LukaCompatLevel level;
  final List<String> messages;
  final String? resolvedFixtureId;
  final Map<String, dynamic>? manualSetup;

  const LukaCompatReport({
    required this.level,
    this.messages = const [],
    this.resolvedFixtureId,
    this.manualSetup,
  });

  bool get isUsable => level != LukaCompatLevel.none;

  String get badgeLabel => switch (level) {
        LukaCompatLevel.full => 'LUKA OK',
        LukaCompatLevel.partial => 'LUKA parcial',
        LukaCompatLevel.manualOnly => 'Setup manual',
        LukaCompatLevel.none => 'Sin LUKA',
      };
}

/// Evalúa compatibilidad LUKA para luces, cámaras y ópticas.
class LukaCompatibilityService {
  LukaCompatibilityService(this._manifest);

  final LukaManifest _manifest;

  static Future<LukaCompatibilityService> create(LukaManifestService service) async {
    final manifest = await service.getManifest();
    return LukaCompatibilityService(manifest);
  }

  LukaCompatReport evaluateLight(Light light) {
    final messages = <String>[];
    final fixtureId = light.lukaFixtureId;
    if (light.isLukaCompatible && fixtureId != null && _manifest.hasFixture(fixtureId)) {
      return LukaCompatReport(
        level: LukaCompatLevel.full,
        resolvedFixtureId: fixtureId,
        messages: ['Fixture ${ _manifest.fixture(fixtureId)?.label ?? fixtureId}'],
      );
    }
    if (light.isLukaCompatible && fixtureId == null) {
      messages.add('Luz marcada LUKA pero sin fixture ID');
    } else if (fixtureId != null && !_manifest.hasFixture(fixtureId)) {
      messages.add('Fixture "$fixtureId" no está en manifest v${_manifest.version}');
    } else {
      messages.add('Sin perfil LUKA — usar luz genérica en UE');
    }
    return LukaCompatReport(
      level: LukaCompatLevel.manualOnly,
      messages: messages,
      manualSetup: _parseProfileJson(light.lukaProfileJson),
    );
  }

  LukaCompatReport evaluateCamera(Camera camera) {
    final profile = _parseProfileJson(camera.lukaProfileJson);
    final preset = profile?['lukaPreset'] as String?;
    final manual = profile?['manualSetup'] == true;

    if (camera.lukaCompatible && preset != null) {
      final inManifest = _manifest.cameraProfiles.any(
        (p) => p.lukaPreset == preset || p.id == preset,
      );
      if (inManifest) {
        return LukaCompatReport(
          level: LukaCompatLevel.full,
          messages: ['Preset LUKA: $preset'],
          manualSetup: profile,
        );
      }
    }

    if (camera.sensorWidthMm > 0 && camera.sensorHeightMm > 0) {
      return LukaCompatReport(
        level: manual ? LukaCompatLevel.manualOnly : LukaCompatLevel.partial,
        messages: [
          if (manual) 'Requiere setup manual en LUKA CineCamera',
          'Sensor ${camera.sensorWidthMm.toStringAsFixed(2)} × '
              '${camera.sensorHeightMm.toStringAsFixed(2)} mm',
        ],
        manualSetup: {
          'sensorWidthMm': camera.sensorWidthMm,
          'sensorHeightMm': camera.sensorHeightMm,
          if (preset != null) 'lukaPreset': preset,
          ...?profile,
        },
      );
    }

    return const LukaCompatReport(
      level: LukaCompatLevel.none,
      messages: ['Datos de sensor insuficientes para LUKA'],
    );
  }

  LukaCompatReport evaluateLens(Lense lens, {Camera? camera}) {
    final profile = _parseProfileJson(lens.lukaProfileJson);
    final manual = profile?['manualSetup'] == true;

    if (lens.lukaCompatible && !manual) {
      return LukaCompatReport(
        level: LukaCompatLevel.partial,
        messages: ['Óptica exportable con CineCamera del proyecto'],
        manualSetup: {
          'focalMm': lens.focalLength > 0 ? lens.focalLength : lens.focalMin,
          'tStop': lens.minTStop,
          'mount': lens.mountType,
          if (lens.isAnamorphic) 'squeezeRatio': lens.squeezeRatio ?? 2.0,
        },
      );
    }

    final focal = lens.focalLength > 0 ? lens.focalLength : lens.focalMin;
    if (focal != null && focal > 0) {
      return LukaCompatReport(
        level: LukaCompatLevel.manualOnly,
        messages: ['Introducir focal ${focal.toStringAsFixed(0)} mm y T${lens.minTStop} en LUKA'],
        manualSetup: {
          'focalMm': focal,
          'tStop': lens.minTStop,
          'mount': lens.mountType,
          'formatCoverage': lens.formatCoverage,
          if (lens.isAnamorphic) 'squeezeRatio': lens.squeezeRatio ?? 2.0,
          if (camera != null) ...{
            'sensorWidthMm': camera.sensorWidthMm,
            'sensorHeightMm': camera.sensorHeightMm,
          },
          ...?profile,
        },
      );
    }

    return const LukaCompatReport(
      level: LukaCompatLevel.none,
      messages: ['Focal no definida — no exportable a LUKA'],
    );
  }

  List<LukaCompatReport> preflightProject({
    required List<Light> lights,
    Camera? camera,
    Lense? lens,
  }) {
    final reports = <LukaCompatReport>[];
    for (final light in lights) {
      final r = evaluateLight(light);
      if (r.level != LukaCompatLevel.full) reports.add(r);
    }
    if (camera != null) {
      final r = evaluateCamera(camera);
      if (r.level != LukaCompatLevel.full) reports.add(r);
    }
    if (lens != null) {
      final r = evaluateLens(lens, camera: camera);
      if (r.level != LukaCompatLevel.full) reports.add(r);
    }
    return reports;
  }

  Map<String, dynamic>? _parseProfileJson(String? jsonStr) {
    if (jsonStr == null || jsonStr.isEmpty) return null;
    try {
      return Map<String, dynamic>.from(
        (jsonDecode(jsonStr) as Map).map(
          (k, v) => MapEntry(k.toString(), v),
        ),
      );
    } catch (_) {
      return null;
    }
  }
}