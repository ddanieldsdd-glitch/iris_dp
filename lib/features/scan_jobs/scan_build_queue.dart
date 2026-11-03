import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/foundation.dart';

import '../../core/database/app_database.dart';
import '../../core/sync/realtime_hub.dart';
import '../camera_plan/rig/scan_builder.dart';
import '../../core/utils/location_scan_metadata.dart';
import '../locations/location_scan_service.dart';
import 'capture_store.dart';

/// Construye una captura (su zip) y va diciendo en qué va.
typedef CaptureBuilder =
    Stream<ScanBuildProgress> Function(String zipPath, String name);

/// En qué va la cola, para el indicador del PC.
class ScanQueueState {
  final int waiting;
  final String? building;
  final double? fraction;

  const ScanQueueState({this.waiting = 0, this.building, this.fraction});

  bool get idle => building == null && waiting == 0;
}

/// La cola del PC (F6.20 · IC.6): las capturas que llegaron del iPhone se
/// construyen de una en una con RealityScan, sin ventana, y el escaneo se
/// pone en su set (o localización). Si IRIS se cierra a mitad, al abrir se
/// vuelve a empezar esa captura.
class ScanBuildQueue {
  final AppDatabase db;
  final CaptureBuilder build;

  /// Aviso del sistema (título, texto).
  final void Function(String title, String body)? notify;

  ScanBuildQueue(this.db, {required this.build, this.notify});

  /// El constructor de verdad: RealityScan de este PC.
  static CaptureBuilder realityScan(RealityScanInstall install) =>
      (zip, name) =>
          ScanBuildJob(source: zip, name: name, realityScan: install).run();

  final state = ValueNotifier(const ScanQueueState());
  bool _running = false;

  /// Las capturas cuyo zip está en este equipo y aún no son escaneo. El zip
  /// solo llega aquí por el receptor, así que no hace falta esperar a que la
  /// fila diga `en_pc`: puede llegar antes el zip que la sincronización.
  Future<List<LocationCapture>> pending() async {
    final out = <LocationCapture>[];
    for (final c in await db.getCapturesWithStatus([
      CaptureStatus.onPhone,
      CaptureStatus.sending,
      CaptureStatus.onPc,
      CaptureStatus.building,
    ])) {
      if (c.uid == null) continue;
      if (await (await CaptureStore.zipFor(c.uid!)).exists()) out.add(c);
    }
    return out;
  }

  /// Construye todo lo pendiente; si ya está construyendo, no hace nada (lo
  /// nuevo se recoge al acabar).
  Future<void> runPending() async {
    if (_running) return;
    _running = true;
    try {
      while (true) {
        final todo = await pending();
        if (todo.isEmpty) break;
        state.value = ScanQueueState(
          waiting: todo.length - 1,
          building: todo.first.name,
        );
        await _buildOne(todo.first);
      }
    } finally {
      _running = false;
      state.value = const ScanQueueState();
    }
  }

  Future<void> _buildOne(LocationCapture c) async {
    final uid = c.uid!;
    final me = await InstallId.get();
    await db.updateCapture(
      uid,
      LocationCapturesCompanion(
        status: const Value(CaptureStatus.building),
        progress: const Value(0),
        builderInstallId: Value(me),
        error: const Value(null),
      ),
    );
    final zip = await CaptureStore.zipFor(uid);
    ScanBuildResult? result;
    String? error;
    var shown = 0.0;
    try {
      await for (final step in build(zip.path, c.name)) {
        final f = step.fraction;
        if (f != null && (f - shown).abs() >= 0.02) {
          shown = f;
          state.value = ScanQueueState(
            waiting: state.value.waiting,
            building: c.name,
            fraction: f,
          );
          await db.updateCapture(
            uid,
            LocationCapturesCompanion(progress: Value(f)),
            touch: false,
          );
        }
        if (step.stage == ScanBuildStage.error) error = step.message;
        if (step.result != null) result = step.result;
      }
    } on Object catch (e) {
      error = '$e';
    }

    if (result == null) {
      await db.updateCapture(
        uid,
        LocationCapturesCompanion(
          status: const Value(CaptureStatus.failed),
          error: Value(error ?? 'RealityScan no dio escaneo'),
        ),
      );
      notify?.call('Escaneo fallido: ${c.name}', error ?? '');
      return;
    }

    try {
      await _attach(c, result.irisGlb);
    } on Object catch (e) {
      await db.updateCapture(
        uid,
        LocationCapturesCompanion(
          status: const Value(CaptureStatus.failed),
          error: Value('No se pudo poner en el set: $e'),
        ),
      );
      return;
    }
    await db.updateCapture(
      uid,
      const LocationCapturesCompanion(
        status: Value(CaptureStatus.done),
        progress: Value(1),
      ),
    );
    // Las fotos ya están en la carpeta del escaneo; el zip sobra.
    await CaptureStore.deleteLocal(uid);
    notify?.call(
      'Escaneo listo: ${c.name}',
      'Ya está en su set; el detalle para Unreal queda en IRIS Escaneos.',
    );
  }

  /// El GLB de IRIS va al set (o a la localización) de la captura.
  Future<void> _attach(LocationCapture c, String glb) async {
    final service = LocationScanService(db);
    final set = c.setId == null ? null : await db.getLocationById(c.setId!);
    if (set != null) {
      await service.importScanForSet(
        projectId: c.projectId,
        set: set,
        sourcePath: glb,
        source: LocationScanSource.iphoneCapture,
      );
      return;
    }
    final site = c.siteId == null ? null : await db.getSiteById(c.siteId!);
    if (site != null) {
      await service.importScanForSite(
        projectId: c.projectId,
        site: site,
        sourcePath: glb,
        source: LocationScanSource.iphoneCapture,
      );
    }
    // Sin set ni localización, el escaneo queda en IRIS Escaneos.
  }
}

/// Aviso de Windows con PowerShell (sin paquetes ni cambios en el
/// instalador). Si falla, no pasa nada: la lista de capturas lo dice igual.
void windowsToast(String title, String body) {
  if (!Platform.isWindows) return;
  String esc(String s) => s
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll("'", "''");
  final script =
      '''
[Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] > \$null
[Windows.Data.Xml.Dom.XmlDocument, Windows.Data.Xml.Dom.XmlDocument, ContentType = WindowsRuntime] > \$null
\$xml = New-Object Windows.Data.Xml.Dom.XmlDocument
\$xml.LoadXml('<toast><visual><binding template="ToastGeneric"><text>${esc(title)}</text><text>${esc(body)}</text></binding></visual></toast>')
\$app = '{1AC14E77-02E7-4E5D-B744-2EB1AE5198B7}\\WindowsPowerShell\\v1.0\\powershell.exe'
[Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier(\$app).Show([Windows.UI.Notifications.ToastNotification]::new(\$xml))
''';
  unawaited(
    Process.run('powershell', [
      '-NoProfile',
      '-WindowStyle',
      'Hidden',
      '-Command',
      script,
    ]).catchError((Object e) {
      debugPrint('Aviso de Windows: $e');
      return ProcessResult(0, 1, '', '');
    }),
  );
}
