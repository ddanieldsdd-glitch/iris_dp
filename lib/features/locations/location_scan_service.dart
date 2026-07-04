import 'dart:io';
import 'dart:ui' as ui;

import 'package:drift/drift.dart' show Value;
import 'package:file_picker/file_picker.dart';

import '../../core/database/app_database.dart';
import '../../core/utils/location_scan_metadata.dart';
import '../../core/utils/media_storage.dart';

/// Importa, persiste y exporta scans de localización / set.
class LocationScanService {
  final AppDatabase db;

  LocationScanService(this.db);

  LocationScanMetadata metadataForSet(LocationBasePlan set) =>
      LocationScanMetadata.fromJson(set.scanMetadataJson);

  LocationScanMetadata metadataForSite(LocationSite site) =>
      LocationScanMetadata.fromJson(site.scanMetadataJson);

  Future<LocationBasePlan?> importScanForSet({
    required int projectId,
    required LocationBasePlan set,
    required String sourcePath,
    String? source,
  }) async {
    final ext = sourcePath.split('.').last.toLowerCase();
    final inferred = source ?? LocationScanSource.inferFromExtension(sourcePath);
    final scanSource = inferred ?? LocationScanSource.manual;

    final stored = await MediaStorage.copyLocationScan(
      projectId: projectId,
      scopeFolder: 'locations',
      scopeId: set.id,
      sourcePath: sourcePath,
      prefix: 'scan',
    );

    String? modelPath = set.model3dPath;
    String? scanPath = set.scanPath;

    if (LocationScanFormats.model3d.contains(ext)) {
      modelPath = stored;
    } else {
      scanPath = stored;
    }

    final meta = metadataForSet(set).copyWith(
      previewImagePath: LocationScanFormats.topDown.contains(ext)
          ? stored
          : metadataForSet(set).previewImagePath,
    );

    await db.updateLocation(set.copyWith(
      scanPath: Value(scanPath),
      scanSource: Value(scanSource),
      model3dPath: Value(modelPath),
      scanMetadataJson: Value(LocationScanMetadata.encode(meta)),
    ));

    return db.getLocationById(set.id);
  }

  Future<LocationSite?> importScanForSite({
    required int projectId,
    required LocationSite site,
    required String sourcePath,
    String? source,
  }) async {
    final inferred = source ?? LocationScanSource.inferFromExtension(sourcePath);
    final scanSource = inferred ?? LocationScanSource.manual;

    final stored = await MediaStorage.copyLocationScan(
      projectId: projectId,
      scopeFolder: 'sites',
      scopeId: site.id,
      sourcePath: sourcePath,
      prefix: 'scan',
    );

    final meta = metadataForSite(site);

    await db.updateSite(site.copyWith(
      scanPath: Value(stored),
      scanSource: Value(scanSource),
      scanMetadataJson: Value(LocationScanMetadata.encode(meta)),
    ));

    return db.getSiteById(site.id);
  }

  Future<LocationBasePlan?> importTopDownForSet({
    required int projectId,
    required LocationBasePlan set,
    required String sourcePath,
    double? metersPerPixel,
  }) async {
    final stored = await MediaStorage.copyLocationScan(
      projectId: projectId,
      scopeFolder: 'locations',
      scopeId: set.id,
      sourcePath: sourcePath,
      prefix: 'topdown',
    );

    final dims = await _imageDimensions(sourcePath);
    final meta = metadataForSet(set).copyWith(
      topDownImagePath: stored,
      topDownWidthPx: dims.width,
      topDownHeightPx: dims.height,
      metersPerPixel: metersPerPixel ?? metadataForSet(set).metersPerPixel,
      previewImagePath: stored,
      useTopDownInFloorPlan: true,
    );

    await db.updateLocation(set.copyWith(
      scanMetadataJson: Value(LocationScanMetadata.encode(meta)),
    ));

    return db.getLocationById(set.id);
  }

  Future<LocationBasePlan?> enableTopDownInFloorPlan({
    required LocationBasePlan set,
    bool enabled = true,
    double? metersPerPixel,
    double? opacity,
  }) async {
    final meta = metadataForSet(set).copyWith(
      useTopDownInFloorPlan: enabled,
      metersPerPixel: metersPerPixel,
      topDownOpacity: opacity,
    );

    await db.updateLocation(set.copyWith(
      scanMetadataJson: Value(LocationScanMetadata.encode(meta)),
    ));

    return db.getLocationById(set.id);
  }

  Future<LocationScanMetadata?> resolveFloorPlanBackground({
    required FloorPlanScopeKind scope,
    int? siteId,
    int? setId,
  }) async {
    switch (scope) {
      case FloorPlanScopeKind.set:
        if (setId == null) return null;
        final set = await db.getLocationById(setId);
        if (set == null) return null;
        final meta = metadataForSet(set);
        if (!meta.useTopDownInFloorPlan || !meta.hasTopDown) return null;
        return meta;
      case FloorPlanScopeKind.site:
        if (siteId == null) return null;
        final site = await db.getSiteById(siteId);
        if (site == null) return null;
        final meta = metadataForSite(site);
        if (!meta.useTopDownInFloorPlan || !meta.hasTopDown) return null;
        return meta;
      case FloorPlanScopeKind.shot:
        if (setId != null) {
          return resolveFloorPlanBackground(
            scope: FloorPlanScopeKind.set,
            setId: setId,
          );
        }
        return null;
    }
  }

  static Future<({double width, double height})> _imageDimensions(
    String path,
  ) async {
    final bytes = await File(path).readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final image = frame.image;
    return (width: image.width.toDouble(), height: image.height.toDouble());
  }

  static Future<String?> pickScanFile() async {
    final result = await FilePicker.platform.pickFiles(
      dialogTitle: 'Importar scan 3D',
      type: FileType.custom,
      allowedExtensions: LocationScanFormats.allScan,
    );
    return result?.files.single.path;
  }

  static Future<String?> pickTopDownImage() async {
    final result = await FilePicker.platform.pickFiles(
      dialogTitle: 'Importar planta cenital',
      type: FileType.custom,
      allowedExtensions: LocationScanFormats.topDown,
    );
    return result?.files.single.path;
  }

  static Future<void> openFileExternally(String path) async {
    if (!File(path).existsSync()) return;
    if (Platform.isMacOS) {
      await Process.run('open', [path]);
    } else if (Platform.isWindows) {
      await Process.run('cmd', ['/c', 'start', '', path]);
    } else if (Platform.isLinux) {
      await Process.run('xdg-open', [path]);
    }
  }
}

enum FloorPlanScopeKind { site, set, shot }
