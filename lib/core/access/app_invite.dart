/// Invitaciones con enlace o con correo (migración 020): el código, el
/// enlace a la página de descarga y el texto que se comparte.
library;

import '../cloud/project_role.dart';

/// Página que abre el enlace: explica qué es IRIS y ofrece la descarga para
/// el equipo de quien la abre. Cuando IRIS tenga dominio propio, solo cambia
/// esta línea (los enlaces ya enviados siguen en la dirección vieja).
const kInvitePageUrl =
    'https://ddanieldsdd-glitch.github.io/iris_dp/invitacion/';

const _codeSigns = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

/// «k7m2-qx9p 4c», un enlace pegado entero o el código suelto → «K7M2QX9P4C».
/// Nulo si no hay un código de 10 signos válidos.
String? normalizeInviteCode(String input) {
  var text = input.trim();
  final param = RegExp(r'[#?&]c=([A-Za-z0-9-]+)').firstMatch(text);
  if (param != null) text = param.group(1)!;
  final code = text.toUpperCase().replaceAll(RegExp('[^A-Z0-9]'), '');
  if (code.length != 10) return null;
  for (final c in code.split('')) {
    if (!_codeSigns.contains(c)) return null;
  }
  return code;
}

/// «K7M2QX9P4C» → «K7M2-QX9P-4C».
String formatInviteCode(String code) => code.length == 10
    ? '${code.substring(0, 4)}-${code.substring(4, 8)}-${code.substring(8)}'
    : code;

/// El enlace lleva el código y, para que la página salude, quién invita y a
/// qué. Va tras «#»: no llega a ningún servidor.
Uri inviteLink({
  required String code,
  String? from,
  String? project,
  ProjectRole? role,
}) {
  final params = <String, String>{
    'c': formatInviteCode(code),
    if (from != null && from.trim().isNotEmpty) 'de': from.trim(),
    if (project != null && project.trim().isNotEmpty) 'p': project.trim(),
    if (role != null) 'r': role.label,
  };
  return Uri.parse(
    kInvitePageUrl,
  ).replace(fragment: Uri(queryParameters: params).query);
}

/// Texto para Correo, WhatsApp o Mensajes.
String inviteMessage({
  required String code,
  String? from,
  String? project,
  ProjectRole? role,
}) {
  final who = from == null || from.trim().isEmpty
      ? 'Te invitan'
      : '${from.trim()} te invita';
  final what = project == null
      ? 'a probar IRIS, la app para preparar la fotografía de un rodaje'
      : 'al proyecto «$project» en IRIS'
            '${role == null ? '' : ' como ${role.label.toLowerCase()}'}';
  final link = inviteLink(code: code, from: from, project: project, role: role);
  return '$who $what.\n\n'
      '1. Descarga IRIS desde aquí: $link\n'
      '2. Ábrela y crea tu cuenta (o entra con la tuya).\n'
      '3. Si te pide un código, escribe ${formatInviteCode(code)}.\n';
}

/// Por qué no vale un código, en palabras.
String inviteErrorText(Object error) {
  final text = error.toString();
  if (text.contains('IRIS_INVITE_UNKNOWN')) {
    return 'Ese código no existe. Revisa que esté bien escrito.';
  }
  if (text.contains('IRIS_INVITE_EXPIRED')) {
    return 'La invitación ha caducado. Pide un enlace nuevo.';
  }
  if (text.contains('IRIS_INVITE_USED')) {
    return 'Esta invitación ya se ha usado. Pide un enlace nuevo.';
  }
  if (text.contains('IRIS_INVITE_REVOKED')) {
    return 'Quien te invitó retiró esta invitación.';
  }
  if (text.contains('IRIS_INVITE_OTHER_EMAIL')) {
    return 'Esta invitación es para otro correo. Entra con el correo al que '
        'te invitaron.';
  }
  if (text.contains('IRIS_INVITE_SIGNIN')) {
    return 'Inicia sesión antes de usar el código.';
  }
  if (text.contains('IRIS_INVITE_FORBIDDEN')) {
    return 'Solo el dueño del proyecto (o el administrador) puede invitar.';
  }
  if (text.contains('IRIS_INVITE_EMAIL')) return 'El correo no es válido.';
  return 'No se pudo completar la invitación. Revisa la conexión y vuelve a '
      'intentarlo.';
}

/// Una invitación creada (lo que ve quien invita).
class AppInvite {
  const AppInvite({
    required this.id,
    required this.code,
    required this.grantsAccess,
    required this.maxUses,
    required this.uses,
    required this.expiresAt,
    this.email,
    this.projectId,
    this.role,
    this.revokedAt,
    this.note,
  });

  final String id;
  final String code;
  final String? email;
  final String? projectId;
  final ProjectRole? role;
  final bool grantsAccess;
  final int maxUses;
  final int uses;
  final DateTime expiresAt;
  final DateTime? revokedAt;
  final String? note;

  /// Aún se puede usar.
  bool isOpen(DateTime now) =>
      revokedAt == null && uses < maxUses && expiresAt.isAfter(now);

  factory AppInvite.fromRow(Map<String, dynamic> row) => AppInvite(
    id: row['id'] as String,
    code: row['code'] as String,
    email: row['email'] as String?,
    projectId: row['project_id'] as String?,
    role: ProjectRole.fromCode(row['project_role'] as String?),
    grantsAccess: row['grants_access'] == true,
    maxUses: (row['max_uses'] as num?)?.toInt() ?? 1,
    uses: (row['uses'] as num?)?.toInt() ?? 0,
    expiresAt: DateTime.parse(row['expires_at'] as String),
    revokedAt: DateTime.tryParse(row['revoked_at'] as String? ?? ''),
    note: row['note'] as String?,
  );
}

/// Resultado de usar una invitación.
class InviteRedemption {
  const InviteRedemption({
    required this.redeemed,
    required this.access,
    required this.projects,
  });

  final int redeemed;

  /// La cuenta ha pasado a tener acceso a IRIS.
  final bool access;
  final List<String> projects;

  static const none = InviteRedemption(
    redeemed: 0,
    access: false,
    projects: [],
  );

  factory InviteRedemption.fromServer(Object? raw) {
    final map = raw is Map ? raw : const {};
    return InviteRedemption(
      redeemed: (map['redeemed'] as num?)?.toInt() ?? 0,
      access: map['access'] == true,
      projects: [for (final p in (map['projects'] as List? ?? const [])) '$p'],
    );
  }
}
