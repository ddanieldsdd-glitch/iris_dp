import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../../../core/database/app_database.dart';
import 'catalog_data.dart';
import 'catalog_models.dart';

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
    lenses = parseLensCatalog(lensesJson);
    lights = parseLightCatalog(lightsJson);
  } catch (_) {
    cameras = kEmbeddedCameras;
    lenses = kEmbeddedLenses;
    lights = kEmbeddedLights;
  }

  await _upsertCameras(db, cameras);
  await _upsertLenses(db, lenses);
  await upsertCatalogLights(db, lights);

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
  await upsertCatalogLights(db, lights);
  await db.upsertCatalogSyncMeta(
    CatalogSyncMetaCompanion(
      remoteVersion: Value(version),
      sourceUrl: Value(sourceUrl),
      lastSyncAt: Value(DateTime.now()),
    ),
  );
}

/// Upsert de cámaras de catálogo oficial (`isCustom=false`).
///
/// No toca filas custom del usuario con el mismo [CatalogCameraEntry.externalId].
/// Devuelve cuántas se escribieron y cuántas se omitieron por ser custom.
Future<({int upserted, int skippedCustom})> upsertCatalogCameras(
  AppDatabase db,
  List<CatalogCameraEntry> entries, {
  bool merge = false,
}) async {
  var upserted = 0;
  var skippedCustom = 0;
  // Con [merge], un campo ausente en la entrada no pisa el que ya existe.
  T? pick<T>(T? incoming, T? current) => merge ? incoming ?? current : incoming;
  for (final e in entries) {
    final existing = await db.getCameraByExternalId(e.externalId);
    if (existing != null) {
      if (existing.isCustom) {
        skippedCustom++;
        continue;
      }
      await db.updateCamera(existing.copyWith(
        brand: e.brand,
        model: e.model,
        sensorWidthMm: e.sensorWidthMm,
        sensorHeightMm: e.sensorHeightMm,
        mountType: Value(pick(e.mountType, existing.mountType)),
        sensorModesJson: Value(
          pick(
            e.sensorModes.isEmpty ? null : jsonEncode(e.sensorModes),
            existing.sensorModesJson,
          ),
        ),
        dynamicRangeStops: Value(pick(e.dynamicRangeStops, existing.dynamicRangeStops)),
        colorScience: Value(pick(e.colorScience, existing.colorScience)),
        nativeIso: Value(pick(e.nativeIso, existing.nativeIso)),
        logFormats: Value(pick(e.logFormats, existing.logFormats)),
        weightKg: Value(pick(e.weightKg, existing.weightKg)),
        powerDrawW: Value(pick(e.powerDrawW?.toDouble(), existing.powerDrawW)),
        manufacturerUrl: Value(pick(e.manufacturerUrl, existing.manufacturerUrl)),
        series: Value(pick(e.series, existing.series)),
        vintage: e.vintage,
        rentalTagsJson: Value(pick(_encodeJsonList(e.rentalTags), existing.rentalTagsJson)),
        lukaCompatible: e.lukaCompatible,
        lukaProfileJson: Value(pick(_encodeProfile(e.lukaProfile), existing.lukaProfileJson)),
        recordingFormats: Value(
          pick(e.recordingFormats, existing.recordingFormats),
        ),
        dataStatus: Value(pick(e.provenance?.status.label, existing.dataStatus)),
        confidence: Value(pick(e.provenance?.confidence, existing.confidence)),
        verifiedFieldsJson: Value(
          pick(e.provenance?.verifiedFieldsJson, existing.verifiedFieldsJson),
        ),
        sourceLabel: Value(pick(e.provenance?.sourceLabel, existing.sourceLabel)),
        sourceUrl: Value(pick(e.provenance?.sourceUrl, existing.sourceUrl)),
        verifiedAt: Value(pick(e.provenance?.verifiedAt, existing.verifiedAt)),
        catalogVersion: const Value(kEmbeddedCatalogVersion),
      ));
      upserted++;
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
        recordingFormats: Value(e.recordingFormats),
        dataStatus: Value(e.provenance?.status.label),
        confidence: Value(e.provenance?.confidence),
        verifiedFieldsJson: Value(e.provenance?.verifiedFieldsJson),
        sourceLabel: Value(e.provenance?.sourceLabel),
        sourceUrl: Value(e.provenance?.sourceUrl),
        verifiedAt: Value(e.provenance?.verifiedAt),
        catalogVersion: const Value(kEmbeddedCatalogVersion),
        isCustom: const Value(false),
      ));
      upserted++;
    }
  }
  return (upserted: upserted, skippedCustom: skippedCustom);
}

Future<void> _upsertCameras(
  AppDatabase db,
  List<CatalogCameraEntry> entries,
) async {
  await upsertCatalogCameras(db, entries);
}

Future<({int upserted, int skippedCustom})> upsertCatalogLenses(
  AppDatabase db,
  List<CatalogLensEntry> entries, {
  bool merge = false,
}) async {
  var upserted = 0;
  var skippedCustom = 0;
  // Con [merge], un campo ausente en la entrada no pisa el que ya existe.
  T? pick<T>(T? incoming, T? current) => merge ? incoming ?? current : incoming;
  for (final e in entries) {
    final existing = await db.getLensByExternalId(e.externalId);
    if (existing != null) {
      if (existing.isCustom) {
        skippedCustom++;
        continue;
      }
      await db.updateLens(existing.copyWith(
        brand: e.brand,
        model: e.model,
        focalLength: e.focalLength,
        focalMin: Value(pick(e.focalMin, existing.focalMin)),
        focalMax: Value(pick(e.focalMax, existing.focalMax)),
        minTStop: e.minTStop,
        formatCoverage: e.formatCoverage,
        mountType: Value(pick(e.mountType, existing.mountType)),
        imageCircleMm: Value(pick(e.imageCircleMm, existing.imageCircleMm)),
        isAnamorphic: e.isAnamorphic,
        squeezeRatio: Value(pick(e.squeezeRatio, existing.squeezeRatio)),
        closeFocusM: Value(pick(e.closeFocusM, existing.closeFocusM)),
        frontDiameterMm: Value(pick(e.frontDiameterMm, existing.frontDiameterMm)),
        lensType: Value(pick(e.lensType, existing.lensType)),
        series: Value(pick(e.series, existing.series)),
        notes: Value(pick(_lensNotesJson(e), existing.notes)),
        vintage: e.vintage,
        rentalTagsJson: Value(pick(_encodeJsonList(e.rentalTags), existing.rentalTagsJson)),
        lukaCompatible: e.lukaCompatible,
        lukaProfileJson: Value(pick(_encodeProfile(e.lukaProfile), existing.lukaProfileJson)),
        projectionType: Value(pick(e.projectionType, existing.projectionType)),
        imageAreaWidthMm: Value(
          pick(e.imageAreaWidthMm, existing.imageAreaWidthMm),
        ),
        imageAreaHeightMm: Value(
          pick(e.imageAreaHeightMm, existing.imageAreaHeightMm),
        ),
        illuminationArea: Value(
          pick(e.illuminationArea, existing.illuminationArea),
        ),
        vignettingStatus: Value(
          pick(e.vignettingStatus, existing.vignettingStatus),
        ),
        shadingStatus: Value(pick(e.shadingStatus, existing.shadingStatus)),
        portholingStatus: Value(
          pick(e.portholingStatus, existing.portholingStatus),
        ),
        specsJson: Value(pick(_encodeProfile(e.specs), existing.specsJson)),
        dataStatus: Value(pick(e.provenance?.status.label, existing.dataStatus)),
        confidence: Value(pick(e.provenance?.confidence, existing.confidence)),
        verifiedFieldsJson: Value(
          pick(e.provenance?.verifiedFieldsJson, existing.verifiedFieldsJson),
        ),
        sourceLabel: Value(pick(e.provenance?.sourceLabel, existing.sourceLabel)),
        sourceUrl: Value(pick(e.provenance?.sourceUrl, existing.sourceUrl)),
        verifiedAt: Value(pick(e.provenance?.verifiedAt, existing.verifiedAt)),
        catalogVersion: const Value(kEmbeddedCatalogVersion),
      ));
      upserted++;
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
        projectionType: Value(e.projectionType),
        imageAreaWidthMm: Value(e.imageAreaWidthMm),
        imageAreaHeightMm: Value(e.imageAreaHeightMm),
        illuminationArea: Value(e.illuminationArea),
        vignettingStatus: Value(e.vignettingStatus),
        shadingStatus: Value(e.shadingStatus),
        portholingStatus: Value(e.portholingStatus),
        specsJson: Value(_encodeProfile(e.specs)),
        dataStatus: Value(e.provenance?.status.label),
        confidence: Value(e.provenance?.confidence),
        verifiedFieldsJson: Value(e.provenance?.verifiedFieldsJson),
        sourceLabel: Value(e.provenance?.sourceLabel),
        sourceUrl: Value(e.provenance?.sourceUrl),
        verifiedAt: Value(e.provenance?.verifiedAt),
        catalogVersion: const Value(kEmbeddedCatalogVersion),
        isCustom: const Value(false),
      ));
      upserted++;
    }
  }
  return (upserted: upserted, skippedCustom: skippedCustom);
}

Future<void> _upsertLenses(AppDatabase db, List<CatalogLensEntry> entries) async {
  await upsertCatalogLenses(db, entries);
}

Future<({int upserted, int skippedCustom})> upsertCatalogLights(
  AppDatabase db,
  List<CatalogLightEntry> entries, {
  bool merge = false,
}) async {
  var upserted = 0;
  var skippedCustom = 0;
  // Con [merge], un campo ausente en la entrada no pisa el que ya existe.
  T? pick<T>(T? incoming, T? current) => merge ? incoming ?? current : incoming;
  for (final e in entries) {
    final existing = await db.getLightByExternalId(e.externalId);
    if (existing != null) {
      if (existing.isCustom) {
        skippedCustom++;
        continue;
      }
      await db.updateLight(existing.copyWith(
        brand: e.brand,
        model: e.model,
        lightType: e.lightType,
        powerW: e.powerW,
        colorTempMin: e.colorTempMin,
        colorTempMax: e.colorTempMax,
        beamAngleDeg: Value(pick(e.beamAngleDeg, existing.beamAngleDeg)),
        cri: Value(pick(e.cri, existing.cri)),
        tlci: Value(pick(e.tlci, existing.tlci)),
        dimmingType: Value(pick(e.dimmingType, existing.dimmingType)),
        isLukaCompatible: e.lukaCompatible,
        lukaFixtureId: Value(pick(e.lukaFixtureId, existing.lukaFixtureId)),
        series: Value(pick(e.series, existing.series)),
        vintage: e.vintage,
        rentalTagsJson: Value(pick(_encodeJsonList(e.rentalTags), existing.rentalTagsJson)),
        lukaProfileJson: Value(pick(_encodeProfile(e.lukaProfile), existing.lukaProfileJson)),
        dataStatus: Value(pick(e.provenance?.status.label, existing.dataStatus)),
        confidence: Value(pick(e.provenance?.confidence, existing.confidence)),
        verifiedFieldsJson: Value(
          pick(e.provenance?.verifiedFieldsJson, existing.verifiedFieldsJson),
        ),
        sourceLabel: Value(pick(e.provenance?.sourceLabel, existing.sourceLabel)),
        sourceUrl: Value(pick(e.provenance?.sourceUrl, existing.sourceUrl)),
        verifiedAt: Value(pick(e.provenance?.verifiedAt, existing.verifiedAt)),
        catalogVersion: const Value(kEmbeddedCatalogVersion),
      ));
      upserted++;
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
        dataStatus: Value(e.provenance?.status.label),
        confidence: Value(e.provenance?.confidence),
        verifiedFieldsJson: Value(e.provenance?.verifiedFieldsJson),
        sourceLabel: Value(e.provenance?.sourceLabel),
        sourceUrl: Value(e.provenance?.sourceUrl),
        verifiedAt: Value(e.provenance?.verifiedAt),
        catalogVersion: const Value(kEmbeddedCatalogVersion),
        isCustom: const Value(false),
      ));
      upserted++;
    }
  }
  return (upserted: upserted, skippedCustom: skippedCustom);
}


