import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../cloud/cloud_providers.dart';
import '../sync/realtime_hub.dart';
import 'device_update_messages.dart';
import 'mac_auto_update.dart';

/// Los archivos con los que IRIS habla con `install_ipad.sh`.
class DeviceUpdateInstallerFiles {
  DeviceUpdateInstallerFiles(this.directory, {File? launchAgent})
      : launchAgent = launchAgent ??
            File(
              '${Platform.environment['HOME'] ?? ''}/Library/LaunchAgents/'
              '$launchdLabel.plist',
            );

  static const launchdLabel = 'com.ddanieldsdd.irisdp.ipad-install';

  factory DeviceUpdateInstallerFiles.standard() => DeviceUpdateInstallerFiles(
        Directory(
          '${Platform.environment['HOME'] ?? ''}/Library/Application Support/'
          'IRIS-DP-installer',
        ),
      );

  final Directory directory;
  final File launchAgent;

  File get _request => File('${directory.path}/request.json');
  File get _status => File('${directory.path}/status.json');

  /// ¿Se ejecutó `setup_ipad_install.sh` en este Mac?
  bool get configured =>
      File('${directory.path}/install_ipad.sh').existsSync() &&
      File('${directory.path}/team_id').existsSync() &&
      launchAgent.existsSync();

  bool get hasPendingRequest => _request.existsSync();

  Future<void> writeRequest(DeviceUpdateRequest request) async {
    final tmp = File('${_request.path}.tmp');
    await tmp.writeAsString(jsonEncode(request.toPayload()), flush: true);
    await tmp.rename(_request.path);
  }

  Future<void> clearRequest() async {
    if (await _request.exists()) await _request.delete();
  }

  Future<DeviceUpdateStatus?> readStatus() async {
    try {
      final data = jsonDecode(await _status.readAsString());
      return data is Map<String, dynamic>
          ? DeviceUpdateStatus.fromPayload(data)
          : null;
    } catch (_) {
      return null;
    }
  }
}

/// Atiende las peticiones de los móviles: se las pasa al instalador y
/// reenvía cómo van. Instala la tarea de launchd, no IRIS, así que sigue
/// aunque IRIS se reinicie a medias.
class DeviceUpdateBridge {
  DeviceUpdateBridge({
    required this.files,
    required this.kickstart,
    required this.currentUserId,
    required this.sendStatus,
    this.pollEvery = const Duration(seconds: 2),
    this.giveUpAfter = const Duration(minutes: 30),
  });

  final DeviceUpdateInstallerFiles files;
  final Future<bool> Function() kickstart;
  final String? Function() currentUserId;
  final Future<void> Function(DeviceUpdateStatus status) sendStatus;
  final Duration pollEvery;
  final Duration giveUpAfter;

  final _deadlines = <String, DateTime>{};
  final _lastPhase = <String, DeviceUpdatePhase>{};
  Timer? _timer;

  Future<void> handle(DeviceUpdateRequest request) async {
    if (request.userId != currentUserId()) return;
    if (_deadlines.containsKey(request.id)) return;
    if (files.hasPendingRequest) {
      await _send(
        request.id,
        DeviceUpdatePhase.error,
        'El Mac tiene otra petición en cola. Prueba en un momento.',
      );
      return;
    }
    try {
      await files.writeRequest(request);
      if (!await kickstart()) throw StateError('launchctl');
    } catch (e) {
      debugPrint('Petición de actualización: $e');
      await files.clearRequest();
      await _send(
        request.id,
        DeviceUpdatePhase.error,
        'El Mac no pudo lanzar la instalación.',
      );
      return;
    }
    _deadlines[request.id] = DateTime.now().add(giveUpAfter);
    await _send(
      request.id,
      DeviceUpdatePhase.pedido,
      'El Mac ha recibido la petición.',
    );
    _timer ??= Timer.periodic(pollEvery, (_) => unawaited(poll()));
  }

  /// Mira `status.json` y reenvía lo que haya cambiado.
  @visibleForTesting
  Future<void> poll() async {
    final status = await files.readStatus();
    if (status != null &&
        _deadlines.containsKey(status.id) &&
        _lastPhase[status.id] != status.phase) {
      _lastPhase[status.id] = status.phase;
      await sendStatus(status);
      if (status.phase.isFinal) _forget(status.id);
    }
    final now = DateTime.now();
    for (final id in [
      for (final e in _deadlines.entries)
        if (e.value.isBefore(now)) e.key,
    ]) {
      _forget(id);
    }
    if (_deadlines.isEmpty) {
      _timer?.cancel();
      _timer = null;
    }
  }

  void _forget(String id) {
    _deadlines.remove(id);
    _lastPhase.remove(id);
  }

  Future<void> _send(String id, DeviceUpdatePhase phase, String message) =>
      sendStatus(DeviceUpdateStatus(id: id, phase: phase, message: message));

  void dispose() {
    _timer?.cancel();
    _timer = null;
  }
}

/// Lanza la tarea programada del instalador.
Future<bool> kickstartDeviceInstaller() async {
  try {
    final id = await Process.run('/usr/bin/id', ['-u']);
    final uid = (id.stdout as String).trim();
    final result = await Process.run('/bin/launchctl', [
      'kickstart',
      'gui/$uid/${DeviceUpdateInstallerFiles.launchdLabel}',
    ]);
    return result.exitCode == 0;
  } catch (e) {
    debugPrint('launchctl: $e');
    return false;
  }
}

/// En el Mac con el instalador configurado: se anuncia a los móviles y
/// atiende sus peticiones. En cualquier otro equipo no hace nada.
class DeviceUpdateHost extends ConsumerStatefulWidget {
  final Widget child;

  const DeviceUpdateHost({super.key, required this.child});

  @override
  ConsumerState<DeviceUpdateHost> createState() => _DeviceUpdateHostState();
}

class _DeviceUpdateHostState extends ConsumerState<DeviceUpdateHost> {
  RealtimeHub? _hub;
  DeviceUpdateBridge? _bridge;
  StreamSubscription<DeviceUpdateRequest>? _requests;

  @override
  void initState() {
    super.initState();
    if (!kReleaseMode || !Platform.isMacOS) return;
    // Una copia de pruebas abierta a la vez no debe responder a los móviles.
    if (!MacAutoUpdate.isInstalledCopy()) return;
    if (!DeviceUpdateInstallerFiles.standard().configured) return;
    ref.listenManual(
      realtimeHubProvider,
      (_, hub) => _attach(hub),
      fireImmediately: true,
    );
  }

  void _attach(RealtimeHub? hub) {
    _detach();
    if (hub == null) return;
    final bridge = DeviceUpdateBridge(
      files: DeviceUpdateInstallerFiles.standard(),
      kickstart: kickstartDeviceInstaller,
      currentUserId: () =>
          ref.read(supabaseClientProvider)?.auth.currentUser?.id,
      sendStatus: hub.sendDeviceUpdateStatus,
    );
    _hub = hub;
    _bridge = bridge;
    _requests = hub.deviceUpdateRequests.listen(
      (request) => unawaited(bridge.handle(request)),
    );
    unawaited(hub.setUpdateHost(true));
  }

  void _detach() {
    unawaited(_requests?.cancel());
    _requests = null;
    _bridge?.dispose();
    _bridge = null;
    unawaited(_hub?.setUpdateHost(false));
    _hub = null;
  }

  @override
  void dispose() {
    _detach();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
