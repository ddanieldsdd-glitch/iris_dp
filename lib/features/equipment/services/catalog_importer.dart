import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../../../core/database/app_database.dart';
import '../data/catalog_data.dart';
import '../data/catalog_models.dart';

String? _encodeJsonList(List<String> items) =>
    items.isEmpty ? null : jsonEncode(items);

String? _encodeProfile(Map<String, dynamic>? profile) =>
    profile == null ? null : jsonEncode(profile);

String? _lensNotesJson(CatalogLensEntry e) {
  final extra = <String, dynamic>{};
  if (e.weightKg != null) extra['weightKg'] = e.weightKg;
  if (e.lengthMm != null) extra['lengthMm'] = e.lengthMm;
  if (e.yearIntroduced != null) extra['year'] = e.yearIntroduced;
  return extra.isEmpty ? null : jsonEncode(extra);
}

List<CatalogLensEntry> _mergeLensCatalogs(
  List<CatalogLensEntry> base,
  List<CatalogLensEntry> expansion,
) {
  final byId = {for (final l in base) l.externalId: l};
  for (final l in expansion) {
    byId[l.externalId] = l;
  }
  return byId.values.toList();
}

List<CatalogCameraEntry> _mergeCameraCatalogs(
  List<CatalogCameraEntry> base,
  List<Map<String, dynamic>> expansionPatches,
) {
  final byId = {for (final c in base) c.externalId: c};
  for (final patch in expansionPatches) {
    final id = patch['externalId'] as String;
    final existing = byId[id];
    if (existing == null) continue;
    final modes = (patch['sensorModes'] as List<dynamic>?)
        ?.map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    if (modes == null || modes.isEmpty) continue;
    byId[id] = CatalogCameraEntry(
      externalId: existing.externalId,
      brand: existing.brand,
      model: existing.model,
      sensorWidthMm: existing.sensorWidthMm,
      sensorHeightMm: existing.sensorHeightMm,
      mountType: existing.mountType,
      sensorModes: modes,
      dynamicRangeStops: existing.dynamicRangeStops,
      colorScience: existing.colorScience,
      nativeIso: existing.nativeIso,
      logFormats: existing.logFormats,
      weightKg: existing.weightKg,
      powerDrawW: existing.powerDrawW,
      manufacturerUrl: existing.manufacturerUrl,
      series: existing.series,
      vintage: existing.vintage,
      rentalTags: existing.rentalTags,
      lukaCompatible: existing.lukaCompatible,
      lukaProfile: existing.lukaProfile,
    );
  }
  return byId.values.toList();
}

List<Map<String, dynamic>> _parseCameraExpansion(String jsonStr) {
  final decoded = jsonDecode(jsonStr);
  if (decoded is List) {
    return decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }
  return const [];
}

/// Importa el catálogo embebido o desde assets JSON.
Future<void> importEmbeddedCatalog(
  AppDatabase db, {
  bool force = false,
}) async {
  final meta = await db.getCatalogSyncMeta();
  if (!force &&
      meta != null &&
      meta.remoteVersion == '$kEmbeddedCatalogVersion') {
    return;
  }

  List<CatalogCameraEntry> cameras;
  List<CatalogLensEntry> lenses;
  List<CatalogLightEntry> lights;

  try {
    final camerasJson = await rootBundle.loadString('assets/catalog/cameras.json');
    final lensesJson = await rootBundle.loadString('assets/catalog/lenses.json');
    final lightsJson = await rootBundle.loadString('assets/catalog/lights.json');
    cameras = parseCameraCatalog(camerasJson);
    try {
      final camerasExpansionJson =
          await rootBundle.loadString('assets/catalog/cameras_expansion.json');
      cameras = _mergeCameraCatalogs(
        cameras,
        _parseCameraExpansion(camerasExpansionJson),
      );
    } catch (_) {}
    var parsedLenses = parseLensCatalog(lensesJson);
    try {
      final expansionJson =
          await rootBundle.loadString('assets/catalog/lenses_expansion.json');
      parsedLenses = _mergeLensCatalogs(
        parsedLenses,
        parseLensCatalog(expansionJson),
      );
    } catch (_) {}
    lenses = parsedLenses;
    lights = parseLightCatalog(lightsJson);
  } catch (_) {
    cameras = kEmbeddedCameras;
    lenses = kEmbeddedLenses;
    lights = kEmbeddedLights;
  }

  await _upsertCameras(db, cameras);
  await _upsertLenses(db, lenses);
  await _upsertLights(db, lights);

  await db.upsertCatalogSyncMeta(
    CatalogSyncMetaCompanion(
      remoteVersion: const Value('$kEmbeddedCatalogVersion'),
      sourceUrl: const Value('embedded'),
      lastSyncAt: Value(DateTime.now()),
    ),
  );
}

Future<void> importCatalogFromJson(
  AppDatabase db, {
  required List<CatalogCameraEntry> cameras,
  required List<CatalogLensEntry> lenses,
  required List<CatalogLightEntry> lights,
  required String version,
  String? sourceUrl,
}) async {
  await _upsertCameras(db, cameras);
  await _upsertLenses(db, lenses);
  await _upsertLights(db, lights);
  await db.upsertCatalogSyncMeta(
    CatalogSyncMetaCompanion(
      remoteVersion: Value(version),
      sourceUrl: Value(sourceUrl),
      lastSyncAt: Value(DateTime.now()),
    ),
  );
}

Future<void> _upsertCameras(
  AppDatabase db,
  List<CatalogCameraEntry> entries,
) async {
  for (final e in entries) {
    final existing = await db.getCameraByExternalId(e.externalId);
    if (existing != null) {
      if (existing.isCustom) continue;
      await db.updateCamera(existing.copyWith(
        brand: e.brand,
        model: e.model,
        sensorWidthMm: e.sensorWidthMm,
        sensorHeightMm: e.sensorHeightMm,
        mountType: Value(e.mountType),
        sensorModesJson: Value(
          e.sensorModes.isEmpty ? null : jsonEncode(e.sensorModes),
        ),
        dynamicRangeStops: Value(e.dynamicRangeStops),
        colorScience: Value(e.colorScience),
        nativeIso: Value(e.nativeIso),
        logFormats: Value(e.logFormats),
        weightKg: Value(e.weightKg),
        powerDrawW: Value(e.powerDrawW?.toDouble()),
        manufacturerUrl: Value(e.manufacturerUrl),
        series: Value(e.series),
        vintage: e.vintage,
        rentalTagsJson: Value(_encodeJsonList(e.rentalTags)),
        lukaCompatible: e.lukaCompatible,
        lukaProfileJson: Value(_encodeProfile(e.lukaProfile)),
        catalogVersion: const Value(kEmbeddedCatalogVersion),
      ));
    } else {
      await db.insertCamera(CamerasCompanion.insert(
        brand: e.brand,
        model: e.model,
        sensorWidthMm: e.sensorWidthMm,
        sensorHeightMm: e.sensorHeightMm,
        mountType: Value(e.mountType),
        sensorModesJson: Value(
          e.sensorModes.isEmpty ? null : jsonEncode(e.sensorModes),
        ),
        dynamicRangeStops: Value(e.dynamicRangeStops),
        colorScience: Value(e.colorScience),
        nativeIso: Value(e.nativeIso),
        logFormats: Value(e.logFormats),
        weightKg: Value(e.weightKg),
        powerDrawW: Value(e.powerDrawW?.toDouble()),
        manufacturerUrl: Value(e.manufacturerUrl),
        series: Value(e.series),
        vintage: Value(e.vintage),
        rentalTagsJson: Value(_encodeJsonList(e.rentalTags)),
        lukaCompatible: Value(e.lukaCompatible),
        lukaProfileJson: Value(_encodeProfile(e.lukaProfile)),
        externalId: Value(e.externalId),
        catalogVersion: const Value(kEmbeddedCatalogVersion),
        isCustom: const Value(false),
      ));
    }
  }
}

Future<void> _upsertLenses(AppDatabase db, List<CatalogLensEntry> entries) async {
  for (final e in entries) {
    final existing = await db.getLensByExternalId(e.externalId);
    if (existing != null) {
      if (existing.isCustom) continue;
      await db.updateLens(existing.copyWith(
        brand: e.brand,
        model: e.model,
        focalLength: e.focalLength,
        focalMin: Value(e.focalMin),
        focalMax: Value(e.focalMax),
        minTStop: e.minTStop,
        formatCoverage: e.formatCoverage,
        mountType: Value(e.mountType),
        imageCircleMm: Value(e.imageCircleMm),
        isAnamorphic: e.isAnamorphic,
        squeezeRatio: Value(e.squeezeRatio),
        closeFocusM: Value(e.closeFocusM),
        frontDiameterMm: Value(e.frontDiameterMm),
        lensType: Value(e.lensType),
        series: Value(e.series),
        notes: Value(_lensNotesJson(e)),
        vintage: e.vintage,
        rentalTagsJson: Value(_encodeJsonList(e.rentalTags)),
        lukaCompatible: e.lukaCompatible,
        lukaProfileJson: Value(_encodeProfile(e.lukaProfile)),
        catalogVersion: const Value(kEmbeddedCatalogVersion),
      ));
    } else {
      await db.insertLens(LensesCompanion.insert(
        brand: e.brand,
        model: e.model,
        focalLength: e.focalLength,
        focalMin: Value(e.focalMin),
        focalMax: Value(e.focalMax),
        minTStop: e.minTStop,
        formatCoverage: e.formatCoverage,
        mountType: Value(e.mountType),
        imageCircleMm: Value(e.imageCircleMm),
        isAnamorphic: Value(e.isAnamorphic),
        squeezeRatio: Value(e.squeezeRatio),
        closeFocusM: Value(e.closeFocusM),
        frontDiameterMm: Value(e.frontDiameterMm),
        lensType: Value(e.lensType),
        series: Value(e.series),
        notes: Value(_lensNotesJson(e)),
        vintage: Value(e.vintage),
        rentalTagsJson: Value(_encodeJsonList(e.rentalTags)),
        lukaCompatible: Value(e.lukaCompatible),
        lukaProfileJson: Value(_encodeProfile(e.lukaProfile)),
        externalId: Value(e.externalId),
        catalogVersion: const Value(kEmbeddedCatalogVersion),
        isCustom: const Value(false),
      ));
    }
  }
}

Future<void> _upsertLights(AppDatabase db, List<CatalogLightEntry> entries) async {
  for (final e in entries) {
    final all = await db.watchAllLights().first;
    final existing = all.where((l) => l.externalId == e.externalId).firstOrNull;
    if (existing != null) {
      if (existing.isCustom) continue;
      await db.updateLight(existing.copyWith(
        brand: e.brand,
        model: e.model,
        lightType: e.lightType,
        powerW: e.powerW,
        colorTempMin: e.colorTempMin,
        colorTempMax: e.colorTempMax,
        beamAngleDeg: Value(e.beamAngleDeg),
        cri: Value(e.cri),
        tlci: Value(e.tlci),
        dimmingType: Value(e.dimmingType),
        isLukaCompatible: e.lukaCompatible,
        lukaFixtureId: Value(e.lukaFixtureId),
        series: Value(e.series),
        vintage: e.vintage,
        rentalTagsJson: Value(_encodeJsonList(e.rentalTags)),
        lukaProfileJson: Value(_encodeProfile(e.lukaProfile)),
        catalogVersion: const Value(kEmbeddedCatalogVersion),
      ));
    } else {
      await db.insertLight(LightsCompanion.insert(
        brand: e.brand,
        model: e.model,
        lightType: e.lightType,
        powerW: e.powerW,
        colorTempMin: e.colorTempMin,
        colorTempMax: e.colorTempMax,
        beamAngleDeg: Value(e.beamAngleDeg),
        cri: Value(e.cri),
        tlci: Value(e.tlci),
        dimmingType: Value(e.dimmingType),
        isLukaCompatible: Value(e.lukaCompatible),
        lukaFixtureId: Value(e.lukaFixtureId),
        series: Value(e.series),
        vintage: Value(e.vintage),
        rentalTagsJson: Value(_encodeJsonList(e.rentalTags)),
        lukaProfileJson: Value(_encodeProfile(e.lukaProfile)),
        externalId: Value(e.externalId),
        catalogVersion: const Value(kEmbeddedCatalogVersion),
        isCustom: const Value(false),
      ));
    }
  }
}

extension _FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull {
    final it = iterator;
    return it.moveNext() ? it.current : null;
  }
}
