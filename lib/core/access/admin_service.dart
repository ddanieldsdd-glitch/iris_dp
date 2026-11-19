import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../cloud/cloud_providers.dart';
import 'app_access.dart';

/// Una cuenta vista por el administrador (`iris_admin_accounts`).
class AdminAccount {
  const AdminAccount({
    required this.userId,
    required this.email,
    required this.displayName,
    required this.isAdmin,
    required this.status,
    required this.projectCount,
    required this.contentBytes,
    required this.historyBytes,
    required this.mediaBytes,
    this.message,
    this.storageLimitBytes,
    this.createdAt,
    this.lastSignInAt,
  });

  final String userId;
  final String email;
  final String displayName;
  final bool isAdmin;
  final AccessStatus status;
  final String? message;
  final int? storageLimitBytes;
  final DateTime? createdAt;
  final DateTime? lastSignInAt;
  final int projectCount;
  final int contentBytes;
  final int historyBytes;
  final int mediaBytes;

  int get totalBytes => contentBytes + historyBytes + mediaBytes;

  String get label => displayName.isNotEmpty ? displayName : email;

  factory AdminAccount.fromJson(Map<String, dynamic> j) {
    int asInt(Object? v) => switch (v) {
      int i => i,
      num n => n.toInt(),
      String s => int.tryParse(s) ?? 0,
      _ => 0,
    };
    return AdminAccount(
      userId: j['user_id'] as String,
      email: j['email'] as String? ?? '',
      displayName: j['display_name'] as String? ?? '',
      isAdmin: j['role'] == 'admin',
      status: AccessStatus.parse(j['status']),
      message: j['message'] as String?,
      storageLimitBytes: j['storage_limit_bytes'] == null
          ? null
          : asInt(j['storage_limit_bytes']),
      createdAt: DateTime.tryParse(j['created_at'] as String? ?? ''),
      lastSignInAt: DateTime.tryParse(j['last_sign_in_at'] as String? ?? ''),
      projectCount: asInt(j['project_count']),
      contentBytes: asInt(j['content_bytes']),
      historyBytes: asInt(j['history_bytes']),
      mediaBytes: asInt(j['media_bytes']),
    );
  }
}

/// Un proyecto de otra cuenta (`iris_admin_projects`).
class GuestProject {
  const GuestProject({
    required this.cloudId,
    required this.name,
    required this.ownerId,
    required this.ownerName,
    required this.iconCode,
    required this.sceneCount,
    required this.shotCount,
    this.director,
    this.status,
    this.contentUpdatedAt,
  });

  final String cloudId;
  final String name;
  final String ownerId;
  final String ownerName;
  final String? director;
  final String? status;
  final int iconCode;
  final int sceneCount;
  final int shotCount;
  final DateTime? contentUpdatedAt;

  factory GuestProject.fromJson(Map<String, dynamic> j) => GuestProject(
    cloudId: j['project_id'] as String,
    name: j['name'] as String? ?? 'Proyecto',
    ownerId: j['owner_id'] as String,
    ownerName: j['owner_name'] as String? ?? '',
    director: j['director_display'] as String?,
    status: j['status'] as String?,
    iconCode: (j['icon_code'] as num?)?.toInt() ?? 0xe3f4,
    sceneCount: (j['scene_count'] as num?)?.toInt() ?? 0,
    shotCount: (j['shot_count'] as num?)?.toInt() ?? 0,
    contentUpdatedAt: DateTime.tryParse(
      j['content_updated_at'] as String? ?? '',
    ),
  );
}

/// Estado general de la app (`app_state`).
class AppStateRow {
  const AppStateRow({
    required this.maintenance,
    required this.minBuild,
    this.message,
  });

  final bool maintenance;
  final String? message;
  final int minBuild;
}

class AdminService {
  AdminService(this._client);

  final SupabaseClient _client;

  Future<List<AdminAccount>> accounts() async {
    final rows = await _client.rpc('iris_admin_accounts');
    return [
      for (final r in rows as List)
        AdminAccount.fromJson(Map<String, dynamic>.from(r as Map)),
    ];
  }

  Future<List<GuestProject>> guestProjects() async {
    final rows = await _client.rpc('iris_admin_projects');
    return [
      for (final r in rows as List)
        GuestProject.fromJson(Map<String, dynamic>.from(r as Map)),
    ];
  }

  Future<AppStateRow> appState() async {
    final row = await _client
        .from('app_state')
        .select('maintenance, message, min_build')
        .eq('id', 1)
        .maybeSingle();
    return AppStateRow(
      maintenance: row?['maintenance'] == true,
      message: row?['message'] as String?,
      minBuild: (row?['min_build'] as num?)?.toInt() ?? 0,
    );
  }

  Future<void> setStatus(String userId, AccessStatus status) => _client.rpc(
    'iris_admin_set_access',
    params: {'p_user': userId, 'p_status': status.name},
  );

  /// Texto vacío borra el mensaje.
  Future<void> setMessage(String userId, String message) => _client.rpc(
    'iris_admin_set_access',
    params: {'p_user': userId, 'p_message': message},
  );

  /// Nulo quita el tope.
  Future<void> setLimit(String userId, int? bytes) => _client.rpc(
    'iris_admin_set_access',
    params: {
      'p_user': userId,
      'p_limit': bytes,
      'p_clear_limit': bytes == null,
    },
  );

  Future<void> setAppState({
    required bool maintenance,
    String? message,
    int? minBuild,
  }) => _client.rpc(
    'iris_admin_set_state',
    params: {
      'p_maintenance': maintenance,
      'p_message': message,
      'p_min_build': minBuild,
    },
  );
}

final adminServiceProvider = Provider<AdminService?>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return client == null ? null : AdminService(client);
});

final adminAccountsProvider = FutureProvider.autoDispose<List<AdminAccount>>(
  (ref) async => await ref.watch(adminServiceProvider)?.accounts() ?? const [],
);

final adminAppStateProvider = FutureProvider.autoDispose<AppStateRow?>(
  (ref) async => ref.watch(adminServiceProvider)?.appState(),
);

final guestProjectsProvider = FutureProvider.autoDispose<List<GuestProject>>(
  (ref) async =>
      await ref.watch(adminServiceProvider)?.guestProjects() ?? const [],
);
