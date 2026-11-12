/// Acceso a la app por cuenta (migración 016): quién entra, mantenimiento,
/// versión mínima y cupo de espacio.
library;

enum AccessStatus {
  pending,
  active,
  suspended;

  static AccessStatus parse(Object? raw) => switch (raw) {
    'active' => AccessStatus.active,
    'suspended' => AccessStatus.suspended,
    _ => AccessStatus.pending,
  };
}

/// Respuesta de `iris_access_check()` y cuándo se obtuvo en este equipo.
class AccessCheck {
  const AccessCheck({
    required this.userId,
    required this.status,
    required this.isAdmin,
    required this.checkedAt,
    this.message,
    this.maintenance = false,
    this.maintenanceMessage,
    this.minBuild = 0,
    this.storageLimitBytes,
    this.usedBytes,
  });

  final String userId;
  final AccessStatus status;
  final bool isAdmin;

  /// Hora de este equipo al recibir la respuesta.
  final DateTime checkedAt;

  /// Mensaje del administrador para esta cuenta.
  final String? message;
  final bool maintenance;
  final String? maintenanceMessage;
  final int minBuild;
  final int? storageLimitBytes;
  final int? usedBytes;

  bool get overQuota {
    final limit = storageLimitBytes;
    final used = usedBytes;
    return limit != null && used != null && used >= limit;
  }

  factory AccessCheck.fromServer(
    Map<String, dynamic> json, {
    required String userId,
    required DateTime checkedAt,
  }) {
    int? asInt(Object? v) => switch (v) {
      int i => i,
      num n => n.toInt(),
      String s => int.tryParse(s),
      _ => null,
    };
    String? text(Object? v) {
      final s = (v as String?)?.trim();
      return s == null || s.isEmpty ? null : s;
    }

    return AccessCheck(
      userId: userId,
      status: AccessStatus.parse(json['status']),
      isAdmin: json['role'] == 'admin',
      checkedAt: checkedAt,
      message: text(json['message']),
      maintenance: json['maintenance'] == true,
      maintenanceMessage: text(json['maintenance_message']),
      minBuild: asInt(json['min_build']) ?? 0,
      storageLimitBytes: asInt(json['storage_limit_bytes']),
      usedBytes: asInt(json['used_bytes']),
    );
  }

  Map<String, dynamic> toJson() => {
    'user_id': userId,
    'status': status.name,
    'role': isAdmin ? 'admin' : 'guest',
    'checked_at': checkedAt.toIso8601String(),
    'message': message,
    'maintenance': maintenance,
    'maintenance_message': maintenanceMessage,
    'min_build': minBuild,
    'storage_limit_bytes': storageLimitBytes,
    'used_bytes': usedBytes,
  };

  static AccessCheck? fromCache(Map<String, dynamic> json) {
    final userId = json['user_id'] as String?;
    final checkedAt = DateTime.tryParse(json['checked_at'] as String? ?? '');
    if (userId == null || checkedAt == null) return null;
    return AccessCheck.fromServer(json, userId: userId, checkedAt: checkedAt);
  }
}

/// Lo que decide la puerta de acceso.
enum AccessVerdict {
  /// Entra.
  open,

  /// Hace falta iniciar sesión (o volver a la nube de IRIS).
  needsSignIn,

  /// Cuenta nueva sin aprobar.
  pending,

  /// El administrador cerró el acceso.
  suspended,

  /// La app está en mantenimiento.
  maintenance,

  /// Esta versión es más antigua que la mínima.
  outdated,

  /// Sin conexión demasiado tiempo (o sin ninguna comprobación).
  offlineExpired,
}

/// Días que vale la última comprobación buena sin conexión.
const kAccessOfflineGrace = Duration(days: 7);

/// Decide si se entra. [fresh] es si [last] acaba de llegar del servidor.
/// El administrador entra siempre que su cuenta esté activa.
AccessVerdict decideAccess({
  required AccessCheck? last,
  required bool fresh,
  required int localBuild,
  required DateTime now,
  Duration grace = kAccessOfflineGrace,
}) {
  if (last == null) return AccessVerdict.offlineExpired;
  switch (last.status) {
    case AccessStatus.pending:
      return AccessVerdict.pending;
    case AccessStatus.suspended:
      return AccessVerdict.suspended;
    case AccessStatus.active:
      break;
  }
  if (last.isAdmin) return AccessVerdict.open;
  if (last.maintenance) return AccessVerdict.maintenance;
  if (last.minBuild > localBuild) return AccessVerdict.outdated;
  if (!fresh) {
    final age = now.difference(last.checkedAt);
    // Un reloj que va hacia atrás no alarga el margen.
    if (age.isNegative || age > grace) return AccessVerdict.offlineExpired;
  }
  return AccessVerdict.open;
}
