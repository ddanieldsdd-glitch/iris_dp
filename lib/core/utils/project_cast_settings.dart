import 'dart:convert';

import 'character_colors.dart';

/// Un grupo de sujetos que se despliega de una vez en la planta.
class CastGroup {
  final String id;
  final String name;

  /// Claves de [characterColorKey], en el orden en que se colocan.
  final List<String> members;

  const CastGroup({
    required this.id,
    required this.name,
    this.members = const [],
  });

  CastGroup copyWith({String? name, List<String>? members}) => CastGroup(
    id: id,
    name: name ?? this.name,
    members: members ?? this.members,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'members': members,
  };
}

/// Lo que se decide sobre el reparto del proyecto. Viaja dentro de
/// `characterColorsJson`, junto a los colores del guion, así que se
/// sincroniza sin esquema nuevo.
class ProjectCastSettings {
  /// No salen en la paleta, pero siguen en la lista de reparto.
  final Set<String> hidden;

  /// Quitados del reparto: no vuelven aunque el guion los siga proponiendo.
  final Set<String> removed;
  final List<CastGroup> groups;

  const ProjectCastSettings({
    this.hidden = const {},
    this.removed = const {},
    this.groups = const [],
  });

  bool get isEmpty => hidden.isEmpty && removed.isEmpty && groups.isEmpty;

  ProjectCastSettings copyWith({
    Set<String>? hidden,
    Set<String>? removed,
    List<CastGroup>? groups,
  }) => ProjectCastSettings(
    hidden: hidden ?? this.hidden,
    removed: removed ?? this.removed,
    groups: groups ?? this.groups,
  );

  /// Oculta o enseña a un sujeto.
  ProjectCastSettings withHidden(String key, bool value) => copyWith(
    hidden: value ? {...hidden, key} : ({...hidden}..remove(key)),
  );

  /// Lo quita del reparto y de sus grupos. Un grupo vacío se conserva: su
  /// nombre es del usuario y puede volver a llenarlo.
  ProjectCastSettings withRemoved(String key) => ProjectCastSettings(
    hidden: {...hidden}..remove(key),
    removed: {...removed, key},
    groups: [
      for (final g in groups)
        g.copyWith(members: [...g.members]..remove(key)),
    ],
  );

  ProjectCastSettings withRestored(String key) =>
      copyWith(removed: {...removed}..remove(key));

  /// Mete o saca a un sujeto de un grupo.
  ProjectCastSettings withMember(String groupId, String key, bool inGroup) =>
      copyWith(
        groups: [
          for (final g in groups)
            if (g.id != groupId)
              g
            else
              g.copyWith(
                members: inGroup
                    ? (g.members.contains(key)
                          ? g.members
                          : [...g.members, key])
                    : ([...g.members]..remove(key)),
              ),
        ],
      );

  Map<String, dynamic> toJson() => {
    if (hidden.isNotEmpty) 'hidden': hidden.toList()..sort(),
    if (removed.isNotEmpty) 'removed': removed.toList()..sort(),
    if (groups.isNotEmpty) 'groups': [for (final g in groups) g.toJson()],
  };

  static ProjectCastSettings fromJson(Object? raw) {
    if (raw is! Map) return const ProjectCastSettings();
    Set<String> keys(Object? list) => list is List
        ? {for (final v in list.whereType<String>()) characterColorKey(v)}
        : const {};
    final groups = <CastGroup>[];
    final rawGroups = raw['groups'];
    if (rawGroups is List) {
      for (final g in rawGroups.whereType<Map>()) {
        final id = g['id'], name = g['name'];
        if (id is! String || name is! String) continue;
        groups.add(
          CastGroup(id: id, name: name, members: keys(g['members']).toList()),
        );
      }
    }
    return ProjectCastSettings(
      hidden: keys(raw['hidden']),
      removed: keys(raw['removed']),
      groups: groups,
    );
  }
}

/// Lee lo decidido sobre el reparto de `characterColorsJson`.
ProjectCastSettings decodeCastSettings(String? json) {
  if (json == null || json.trim().isEmpty) {
    return const ProjectCastSettings();
  }
  try {
    final decoded = jsonDecode(json);
    if (decoded is! Map) return const ProjectCastSettings();
    return ProjectCastSettings.fromJson(decoded[kCastSettingsKey]);
  } catch (_) {
    return const ProjectCastSettings();
  }
}

/// `characterColorsJson` con [settings], sin tocar colores ni marcas del guion.
String? encodeCastSettings(String? json, ProjectCastSettings settings) {
  Map<String, dynamic> payload = {};
  if (json != null && json.trim().isNotEmpty) {
    try {
      final decoded = jsonDecode(json);
      if (decoded is Map) payload = Map<String, dynamic>.from(decoded);
    } catch (_) {}
  }
  if (settings.isEmpty) {
    payload.remove(kCastSettingsKey);
  } else {
    payload[kCastSettingsKey] = settings.toJson();
  }
  return payload.isEmpty ? null : jsonEncode(payload);
}
