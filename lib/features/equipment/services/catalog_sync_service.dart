import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;

import '../../../core/database/app_database.dart';
import '../data/catalog_data.dart';
import '../data/catalog_models.dart';
import 'catalog_importer.dart' as catalog_importer;

/// URL base opcional para sync remoto del catálogo IRIS.
const kDefaultCatalogRemoteUrl =
    'https://raw.githubusercontent.com/iris-dp/catalog/main';

class CatalogSyncResult {
  final bool updated;
  final String? message;
  final int cameras;
  final int lenses;
  final int lights;

  const CatalogSyncResult({
    required this.updated,
    this.message,
    this.cameras = 0,
    this.lenses = 0,
    this.lights = 0,
  });
}

class CatalogSyncService {
  CatalogSyncService(this._db);

  final AppDatabase _db;

  Future<CatalogSyncResult> importEmbeddedCatalog({bool force = false}) async {
    await catalog_importer.importEmbeddedCatalog(_db, force: force);
    final cameras = await _db.watchAllCameras().first;
    final lenses = await _db.watchAllLenses().first;
    final lights = await _db.watchAllLights().first;
    return CatalogSyncResult(
      updated: true,
      message: 'Catálogo embebido v$kEmbeddedCatalogVersion',
      cameras: cameras.length,
      lenses: lenses.length,
      lights: lights.length,
    );
  }

  Future<CatalogSyncResult> checkRemoteUpdates({
    String baseUrl = kDefaultCatalogRemoteUrl,
  }) async {
    try {
      final meta = await _db.getCatalogSyncMeta();
      final localVersion = int.tryParse(meta?.remoteVersion ?? '0') ?? 0;

      final manifestResp = await http.get(Uri.parse('$baseUrl/manifest.json'));
      if (manifestResp.statusCode != 200) {
        return CatalogSyncResult(
          updated: false,
          message: 'No se pudo contactar el catálogo remoto (${manifestResp.statusCode})',
        );
      }

      final manifest =
          CatalogManifest.fromJson(jsonDecode(manifestResp.body) as Map<String, dynamic>);
      if (manifest.version <= localVersion) {
        return CatalogSyncResult(
          updated: false,
          message: 'Catálogo actualizado (v$localVersion)',
        );
      }

      final camerasResp = await http.get(Uri.parse('$baseUrl/${manifest.camerasUrl}'));
      final lensesResp = await http.get(Uri.parse('$baseUrl/${manifest.lensesUrl}'));
      final lightsResp = await http.get(Uri.parse('$baseUrl/${manifest.lightsUrl}'));

      if (camerasResp.statusCode != 200 ||
          lensesResp.statusCode != 200 ||
          lightsResp.statusCode != 200) {
        return const CatalogSyncResult(
          updated: false,
          message: 'Error descargando packs del catálogo',
        );
      }

      await catalog_importer.importCatalogFromJson(
        _db,
        cameras: parseCameraCatalog(camerasResp.body),
        lenses: parseLensCatalog(lensesResp.body),
        lights: parseLightCatalog(lightsResp.body),
        version: '${manifest.version}',
        sourceUrl: baseUrl,
      );

      return CatalogSyncResult(
        updated: true,
        message: 'Catálogo actualizado a v${manifest.version}',
        cameras: parseCameraCatalog(camerasResp.body).length,
        lenses: parseLensCatalog(lensesResp.body).length,
        lights: parseLightCatalog(lightsResp.body).length,
      );
    } catch (e) {
      return CatalogSyncResult(
        updated: false,
        message: 'Sync remoto no disponible: $e',
      );
    }
  }

  Future<String?> loadEmbeddedManifestJson() async {
    try {
      return await rootBundle.loadString('assets/catalog/manifest.json');
    } catch (_) {
      return jsonEncode(kEmbeddedManifest.toJson());
    }
  }
}
