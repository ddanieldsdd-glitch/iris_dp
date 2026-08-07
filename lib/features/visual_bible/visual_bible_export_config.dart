import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'visual_bible_model.dart';

/// Audiencia del PDF: documento general o ficha por departamento.
enum VisualBibleExportAudience {
  general,
  customized,
}

/// Destino tras generar el PDF.
enum VisualBibleExportDestination {
  saveFile,
  share,
}

/// Configuración de exportación de la Biblia de Fotografía.
class VisualBibleExportConfig {
  final String id;
  final String name;
  final VisualBibleExportAudience audience;
  final String mode;
  final String? department;
  final String recipients;
  final Set<String> sections;
  final VisualBibleExportDestination destination;
  final DateTime updatedAt;

  const VisualBibleExportConfig({
    required this.id,
    required this.name,
    required this.audience,
    required this.mode,
    this.department,
    this.recipients = '',
    required this.sections,
    required this.destination,
    required this.updatedAt,
  });

  factory VisualBibleExportConfig.defaults() {
    return VisualBibleExportConfig(
      id: 'default',
      name: 'Documento general',
      audience: VisualBibleExportAudience.general,
      mode: VisualBibleExportMode.full,
      sections: defaultSectionsForMode(VisualBibleExportMode.full),
      destination: VisualBibleExportDestination.saveFile,
      updatedAt: DateTime.now(),
    );
  }

  static Set<String> defaultSectionsForMode(String mode) => switch (mode) {
        VisualBibleExportMode.pitch => {
            BibleSectionId.direction,
            BibleSectionId.concept,
            BibleSectionId.colorImage,
            BibleSectionId.moodboard,
          },
        VisualBibleExportMode.techScout => {
            BibleSectionId.lighting,
            BibleSectionId.exposure,
            BibleSectionId.camera,
            BibleSectionId.optics,
            BibleSectionId.cameraTests,
            BibleSectionId.location,
          },
        _ => BibleSectionId.all.toSet(),
      };

  static Set<String> defaultSectionsForDepartment(String department) =>
      switch (department) {
        VisualBibleDepartment.gaffer => {
            BibleSectionId.lighting,
            BibleSectionId.exposure,
            BibleSectionId.location,
            BibleSectionId.camera,
          },
        VisualBibleDepartment.colorist => {
            BibleSectionId.colorImage,
            BibleSectionId.texture,
            BibleSectionId.moodboard,
            BibleSectionId.workflow,
          },
        VisualBibleDepartment.cameraOp => {
            BibleSectionId.camera,
            BibleSectionId.optics,
            BibleSectionId.exposure,
            BibleSectionId.format,
          },
        VisualBibleDepartment.productionDesign => {
            BibleSectionId.direction,
            BibleSectionId.concept,
            BibleSectionId.location,
            BibleSectionId.colorImage,
            BibleSectionId.moodboard,
          },
        _ => BibleSectionId.all.toSet(),
      };

  bool get isDepartment =>
      audience == VisualBibleExportAudience.customized &&
      department != null &&
      department!.isNotEmpty;

  String get summaryLabel {
    if (isDepartment) {
      final dept = VisualBibleDepartment.label(department!);
      if (recipients.trim().isEmpty) return 'Ficha · $dept';
      return 'Ficha · $dept · ${recipients.trim()}';
    }
    return VisualBibleExportMode.label(mode);
  }

  VisualBibleExportConfig copyWith({
    String? id,
    String? name,
    VisualBibleExportAudience? audience,
    String? mode,
    String? department,
    String? recipients,
    Set<String>? sections,
    VisualBibleExportDestination? destination,
    DateTime? updatedAt,
    bool clearDepartment = false,
  }) {
    return VisualBibleExportConfig(
      id: id ?? this.id,
      name: name ?? this.name,
      audience: audience ?? this.audience,
      mode: mode ?? this.mode,
      department: clearDepartment ? null : (department ?? this.department),
      recipients: recipients ?? this.recipients,
      sections: sections ?? this.sections,
      destination: destination ?? this.destination,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'audience': audience.name,
        'mode': mode,
        'department': department,
        'recipients': recipients,
        'sections': sections.toList(),
        'destination': destination.name,
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory VisualBibleExportConfig.fromJson(Map<String, dynamic> json) {
    final audienceName = json['audience'] as String? ?? 'general';
    final destName = json['destination'] as String? ?? 'saveFile';
    final rawSections = (json['sections'] as List?)?.cast<String>() ??
        BibleSectionId.all;
    return VisualBibleExportConfig(
      id: json['id'] as String? ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      name: json['name'] as String? ?? 'Sin nombre',
      audience: VisualBibleExportAudience.values.firstWhere(
        (e) => e.name == audienceName,
        orElse: () => VisualBibleExportAudience.general,
      ),
      mode: json['mode'] as String? ?? VisualBibleExportMode.full,
      department: json['department'] as String?,
      recipients: json['recipients'] as String? ?? '',
      sections: rawSections.toSet(),
      destination: VisualBibleExportDestination.values.firstWhere(
        (e) => e.name == destName,
        orElse: () => VisualBibleExportDestination.saveFile,
      ),
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}

/// Presets de export guardados por proyecto (edición futura / backup / entrega).
abstract final class VisualBibleExportConfigStore {
  static String _presetsKey(int projectId) =>
      'iris_bible_export_presets_$projectId';
  static String _lastKey(int projectId) =>
      'iris_bible_export_last_$projectId';

  static Future<List<VisualBibleExportConfig>> loadAll(int projectId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_presetsKey(projectId));
    if (raw == null || raw.isEmpty) return const [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      final configs = list
          .whereType<Map>()
          .map((e) => VisualBibleExportConfig.fromJson(
                Map<String, dynamic>.from(e),
              ))
          .toList()
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return configs;
    } catch (_) {
      return const [];
    }
  }

  static Future<void> save(int projectId, VisualBibleExportConfig config) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = await loadAll(projectId);
    final next = [
      config.copyWith(updatedAt: DateTime.now()),
      ...existing.where((e) => e.id != config.id),
    ];
    await prefs.setString(
      _presetsKey(projectId),
      jsonEncode(next.map((e) => e.toJson()).toList()),
    );
    await saveLast(projectId, config);
  }

  static Future<void> delete(int projectId, String id) async {
    final prefs = await SharedPreferences.getInstance();
    final next = (await loadAll(projectId)).where((e) => e.id != id).toList();
    await prefs.setString(
      _presetsKey(projectId),
      jsonEncode(next.map((e) => e.toJson()).toList()),
    );
  }

  static Future<VisualBibleExportConfig?> loadLast(int projectId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_lastKey(projectId));
    if (raw == null || raw.isEmpty) return null;
    try {
      return VisualBibleExportConfig.fromJson(
        Map<String, dynamic>.from(jsonDecode(raw) as Map),
      );
    } catch (_) {
      return null;
    }
  }

  static Future<void> saveLast(
    int projectId,
    VisualBibleExportConfig config,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastKey(projectId), jsonEncode(config.toJson()));
  }
}
