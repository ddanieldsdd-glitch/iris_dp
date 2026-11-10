import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../cloud/cloud_providers.dart';
import '../sync/device_label.dart';
import '../sync/realtime_hub.dart';
import 'device_update_messages.dart';

/// El lado del iPad o iPhone: pide al Mac que lo actualice y cuenta cómo va.
class DeviceUpdateController extends ChangeNotifier {
  DeviceUpdateController({
    required this.kind,
    required this.userId,
    required this.send,
    this.ackTimeout = const Duration(seconds: 20),
    this.finishTimeout = const Duration(minutes: 25),
  });

  final String kind;
  final String? Function() userId;
  final Future<void> Function(DeviceUpdateRequest request) send;
  final Duration ackTimeout;
  final Duration finishTimeout;

  bool _hostAvailable = false;
  String? _requestId;
  DeviceUpdatePhase? _phase;
  String? _message;
  Timer? _timeout;
  int _sequence = 0;

  /// ¿Hay un Mac con IRIS abierta que pueda instalar?
  bool get hostAvailable => _hostAvailable;

  /// Hay una petición en curso.
  bool get busy => _requestId != null;

  DeviceUpdatePhase? get phase => _phase;

  /// Lo último que hay que decir sobre la petición.
  String? get message => _message;

  void setHostAvailable(bool value) {
    if (value == _hostAvailable) return;
    _hostAvailable = value;
    notifyListeners();
  }

  Future<void> request() async {
    if (busy || !_hostAvailable) return;
    final user = userId();
    if (user == null) {
      _finish(DeviceUpdatePhase.error, 'Inicia sesión para pedirlo al Mac.');
      return;
    }
    final id = '${DateTime.now().microsecondsSinceEpoch}-${_sequence++}';
    _requestId = id;
    _phase = DeviceUpdatePhase.pedido;
    _message = 'Pidiendo al Mac que actualice IRIS…';
    _waitFor(ackTimeout, 'El Mac no responde. Comprueba que IRIS esté abierta en él.');
    notifyListeners();
    await send(DeviceUpdateRequest(id: id, kind: kind, userId: user));
  }

  void onStatus(DeviceUpdateStatus status) {
    if (status.id != _requestId) return;
    if (status.phase.isFinal) {
      _finish(status.phase, status.message);
      return;
    }
    _phase = status.phase;
    _message = status.message;
    _waitFor(finishTimeout, 'El Mac no ha terminado. Mira el registro en el Mac.');
    notifyListeners();
  }

  void _waitFor(Duration limit, String messageIfExpired) {
    _timeout?.cancel();
    _timeout = Timer(limit, () => _finish(DeviceUpdatePhase.error, messageIfExpired));
  }

  void _finish(DeviceUpdatePhase phase, String message) {
    _timeout?.cancel();
    _requestId = null;
    _phase = phase;
    _message = message;
    notifyListeners();
  }

  @override
  void dispose() {
    _timeout?.cancel();
    super.dispose();
  }
}

final deviceUpdateProvider =
    ChangeNotifierProvider<DeviceUpdateController>((ref) {
  final hub = ref.watch(realtimeHubProvider);
  final controller = DeviceUpdateController(
    kind: deviceLabel(),
    userId: () => ref.read(supabaseClientProvider)?.auth.currentUser?.id,
    send: (request) async => hub?.sendDeviceUpdateRequest(request),
  );
  if (hub != null) {
    void syncHost() => controller.setHostAvailable(hub.updateHostAvailable.value);
    syncHost();
    hub.updateHostAvailable.addListener(syncHost);
    final statuses = hub.deviceUpdateStatuses.listen(controller.onStatus);
    ref.onDispose(() {
      hub.updateHostAvailable.removeListener(syncHost);
      unawaited(statuses.cancel());
    });
  }
  return controller;
});
