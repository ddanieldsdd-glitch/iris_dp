import 'package:supabase_flutter/supabase_flutter.dart';

import '../cloud/project_role.dart';
import 'app_access_service.dart';
import 'app_invite.dart';

/// La nube aún no tiene la migración 020.
class InviteLinksUnavailable implements Exception {
  const InviteLinksUnavailable();

  @override
  String toString() =>
      'Falta la migración 020 en Supabase: aún no se pueden crear enlaces.';
}

/// Crear, usar y retirar invitaciones (020).
class AppInviteService {
  AppInviteService(this._client);

  final SupabaseClient _client;

  Future<T> _guard<T>(Future<T> Function() op) async {
    try {
      return await op();
    } on PostgrestException catch (e) {
      if (AppAccessService.isMissingFunction(e) || e.code == '42P01') {
        throw const InviteLinksUnavailable();
      }
      rethrow;
    }
  }

  /// Sin [projectCloudId], invita a IRIS (solo el administrador). Con
  /// [email], solo esa cuenta puede usarla y se aplica sola al entrar.
  Future<AppInvite> create({
    String? projectCloudId,
    ProjectRole? role,
    String? email,
    int maxUses = 1,
    int validDays = 30,
    int? planDays,
    String? note,
  }) => _guard(() async {
    final raw = await _client.rpc(
      'iris_create_invite',
      params: {
        'p_project': projectCloudId,
        'p_role': role?.code,
        'p_email': email,
        'p_max_uses': maxUses,
        'p_valid_days': validDays,
        'p_plan_days': planDays,
        'p_note': note,
      },
    );
    final map = Map<String, dynamic>.from(raw as Map);
    return AppInvite(
      id: map['id'] as String,
      code: map['code'] as String,
      grantsAccess: map['grants_access'] == true,
      maxUses: email == null ? maxUses : 1,
      uses: 0,
      expiresAt: DateTime.parse(map['expires_at'] as String),
      email: email?.trim().toLowerCase(),
      projectId: projectCloudId,
      role: role,
      note: note,
    );
  });

  /// Con [code], esa invitación (lanza si no vale: ver [inviteErrorText]).
  /// Sin código, las que haya para el correo de esta cuenta.
  Future<InviteRedemption> redeem([String? code]) => _guard(() async {
    final raw = await _client.rpc(
      'iris_redeem_invite',
      params: {'p_code': code},
    );
    return InviteRedemption.fromServer(raw);
  });

  /// Las que ha creado esta cuenta (todas, si es el administrador), de un
  /// proyecto o solo las de IRIS sin proyecto.
  Future<List<AppInvite>> list({
    String? projectCloudId,
    bool appOnly = false,
  }) => _guard(() async {
    var query = _client.from('app_invites').select();
    if (projectCloudId != null) {
      query = query.eq('project_id', projectCloudId);
    } else if (appOnly) {
      query = query.isFilter('project_id', null);
    }
    final rows = await query.order('created_at', ascending: false);
    return [
      for (final r in rows as List)
        AppInvite.fromRow(Map<String, dynamic>.from(r as Map)),
    ];
  });

  Future<void> revoke(String id) =>
      _guard(() => _client.rpc('iris_revoke_invite', params: {'p_id': id}));
}
