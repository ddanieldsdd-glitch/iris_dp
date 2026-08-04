import 'package:drift/drift.dart';

import '../../core/database/app_database.dart';
import 'luka_manifest_models.dart';

/// Carga y sincroniza el manifest LUKA embebido.
class LukaManifestService {
  LukaManifestService(this._db);

  final AppDatabase _db;
  LukaManifest? _cached;

  Future<LukaManifest> getManifest({bool reload = false}) async {
    if (_cached != null && !reload) return _cached!;
    _cached = await loadEmbeddedLukaManifest();
    return _cached!;
  }

  Future<void> recordSyncCheck() async {
    final manifest = await getManifest();
    await _db.upsertLukaSyncMeta(
      LukaSyncMetaCompanion(
        remoteVersion: Value('${manifest.version}'),
        sourceUrl: const Value('embedded'),
        lastSyncAt: Value(DateTime.now()),
      ),
    );
  }

  Future<String?> lastSyncVersion() async {
    final meta = await _db.getLukaSyncMeta();
    return meta?.remoteVersion;
  }
}
