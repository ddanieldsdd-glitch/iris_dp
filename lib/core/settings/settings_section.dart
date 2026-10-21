import 'package:flutter/material.dart';

import 'app_prefs.dart';

/// Grupos del lateral del centro de ajustes.
enum SettingsGroup {
  app('App'),
  screens('Pantallas');

  final String label;
  const SettingsGroup(this.label);
}

/// Una sección del centro de ajustes. El centro y el engranaje de cada
/// pantalla leen la misma lista, así que cada sección se escribe una vez.
class SettingsSectionSpec {
  final String id;
  final String title;
  final IconData icon;
  final Color color;
  final SettingsGroup group;

  /// Frase bajo el título.
  final String? description;

  /// Ajustes con alcance de la sección: si hay alguno, la sección admite
  /// excepción por proyecto y el lateral cuenta las que tiene.
  final List<PrefKey> prefKeys;

  /// Palabras extra para el buscador.
  final List<String> keywords;

  final Widget Function(BuildContext context, SettingsScope scope) builder;

  const SettingsSectionSpec({
    required this.id,
    required this.title,
    required this.icon,
    required this.color,
    required this.group,
    required this.builder,
    this.description,
    this.prefKeys = const [],
    this.keywords = const [],
  });

  bool get scoped => prefKeys.isNotEmpty;

  bool matches(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;
    return title.toLowerCase().contains(q) ||
        keywords.any((k) => k.toLowerCase().contains(q));
  }
}
