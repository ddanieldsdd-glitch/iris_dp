/// Perfil de una persona del workspace (tabla `profiles` de Supabase).
class UserProfile {
  const UserProfile({
    required this.id,
    required this.displayName,
    this.avatarUrl,
    this.role,
    this.email,
  });

  final String id;
  final String displayName;

  /// URL pública de la foto (bucket `avatars`), con `?v=` para romper caché.
  final String? avatarUrl;

  /// `dp`, `director`, `owner`, `viewer`… según de dónde salga.
  final String? role;

  /// Solo se conoce para el usuario con sesión.
  final String? email;

  bool get hasAvatar => avatarUrl != null && avatarUrl!.isNotEmpty;

  /// Nombre a mostrar: el del perfil, o la parte del email antes de la @.
  String get label {
    final name = displayName.trim();
    if (name.isNotEmpty) return name;
    final mail = email?.split('@').first.trim() ?? '';
    return mail.isNotEmpty ? mail : 'Sin nombre';
  }

  String get initials => initialsFor(label);

  UserProfile copyWith({
    String? displayName,
    String? avatarUrl,
    bool clearAvatar = false,
    String? role,
    String? email,
  }) {
    return UserProfile(
      id: id,
      displayName: displayName ?? this.displayName,
      avatarUrl: clearAvatar ? null : (avatarUrl ?? this.avatarUrl),
      role: role ?? this.role,
      email: email ?? this.email,
    );
  }

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String,
      displayName: (json['display_name'] as String?) ?? '',
      avatarUrl: json['avatar_url'] as String?,
      role: json['role'] as String?,
      email: json['email'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'display_name': displayName,
    'avatar_url': avatarUrl,
    'role': role,
    'email': email,
  };

  @override
  bool operator ==(Object other) =>
      other is UserProfile &&
      other.id == id &&
      other.displayName == displayName &&
      other.avatarUrl == avatarUrl &&
      other.role == role &&
      other.email == email;

  @override
  int get hashCode => Object.hash(id, displayName, avatarUrl, role, email);
}

/// «Daniel Díaz» → «DD»; «daniel» → «D»; vacío → «?».
String initialsFor(String name) {
  final words = name
      .trim()
      .split(RegExp(r'[\s._-]+'))
      .where((w) => w.isNotEmpty)
      .toList();
  if (words.isEmpty) return '?';
  String firstOf(String w) => String.fromCharCode(w.runes.first);
  if (words.length == 1) return firstOf(words.first).toUpperCase();
  return (firstOf(words.first) + firstOf(words.last)).toUpperCase();
}

/// Nombre del rol para la interfaz.
String roleLabel(String? role) => switch (role) {
  'owner' || 'dp' => 'DP',
  'director' => 'Director',
  'viewer' => 'Solo lectura',
  'collaborator' => 'Colaborador',
  _ => 'Sin rol',
};
