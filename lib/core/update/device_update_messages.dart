/// Mensajes entre el iPad o iPhone que pide una actualización y el Mac que
/// la instala (van por el canal en vivo, ver `RealtimeHub`).
library;

/// En qué va la petición. Las fases llegan tal cual desde `install_ipad.sh`,
/// salvo [pedido], que la añade el Mac al recibirla.
enum DeviceUpdatePhase {
  pedido,
  compilando,
  instalando,
  hecho,
  aldia,
  error;

  bool get isFinal => this == hecho || this == aldia || this == error;

  static DeviceUpdatePhase? fromWire(Object? value) {
    for (final phase in values) {
      if (phase.name == value) return phase;
    }
    return null;
  }
}

/// Un iPad o iPhone pide al Mac que lo actualice ahora.
class DeviceUpdateRequest {
  final String id;

  /// `iPad` o `iPhone`: el Mac instala en el dispositivo emparejado de ese
  /// tipo (iOS no deja a la app saber su identificador).
  final String kind;

  /// Quién lo pide: el canal es del espacio de trabajo y puede ser compartido.
  final String userId;

  const DeviceUpdateRequest({
    required this.id,
    required this.kind,
    required this.userId,
  });

  Map<String, dynamic> toPayload() => {
        'id': id,
        'kind': kind,
        'userId': userId,
      };

  static DeviceUpdateRequest? fromPayload(Map<String, dynamic> p) {
    final id = p['id'];
    final kind = p['kind'];
    final userId = p['userId'];
    if (id is! String || id.isEmpty || userId is! String || userId.isEmpty) {
      return null;
    }
    if (kind != 'iPad' && kind != 'iPhone') return null;
    return DeviceUpdateRequest(id: id, kind: kind as String, userId: userId);
  }
}

/// Cómo va una petición. También es el contenido de `status.json`.
class DeviceUpdateStatus {
  final String id;
  final DeviceUpdatePhase phase;
  final String message;

  const DeviceUpdateStatus({
    required this.id,
    required this.phase,
    required this.message,
  });

  Map<String, dynamic> toPayload() => {
        'id': id,
        'phase': phase.name,
        'message': message,
      };

  static DeviceUpdateStatus? fromPayload(Map<String, dynamic> p) {
    final id = p['id'];
    final phase = DeviceUpdatePhase.fromWire(p['phase']);
    final message = p['message'];
    if (id is! String || phase == null || message is! String) return null;
    return DeviceUpdateStatus(id: id, phase: phase, message: message);
  }
}
