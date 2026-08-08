import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/database/app_database.dart';
import '../../shared/annotations/annotation_document.dart';

/// Trazo de anotación (coords normalizadas 0–1 respecto al frame).
class MoodboardStroke {
  final String id;
  final Color color;
  final double width;
  final List<Offset> points; // normalized
  final String? label;

  const MoodboardStroke({
    required this.id,
    required this.color,
    required this.width,
    required this.points,
    this.label,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'color': color.toARGB32(),
    'width': width,
    'label': label,
    'points': points.map((p) => [p.dx, p.dy]).toList(),
  };

  factory MoodboardStroke.fromJson(Map<String, dynamic> json) {
    final pts =
        (json['points'] as List?)?.map((e) {
          final a = e as List;
          return Offset((a[0] as num).toDouble(), (a[1] as num).toDouble());
        }).toList() ??
        <Offset>[];
    final colorInt = json['color'] as int? ?? 0xFF2997FF;
    return MoodboardStroke(
      id:
          json['id'] as String? ??
          DateTime.now().microsecondsSinceEpoch.toString(),
      color: Color(colorInt),
      width: (json['width'] as num?)?.toDouble() ?? 3,
      points: pts,
      label: json['label'] as String?,
    );
  }
}

abstract final class MoodboardAnnotationStore {
  static const annotationTargetType = 'moodboard_image';

  static String _strokesKey(int imageId) => 'moodboard_strokes_$imageId';
  static String _resolvedKey(int imageId) => 'moodboard_resolved_$imageId';

  static Future<List<MoodboardStroke>> loadStrokes(int imageId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_strokesKey(imageId));
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list
          .whereType<Map>()
          .map((e) => MoodboardStroke.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveStrokes(
    int imageId,
    List<MoodboardStroke> strokes,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _strokesKey(imageId),
      jsonEncode(strokes.map((s) => s.toJson()).toList()),
    );
  }

  static Future<Set<int>> loadResolved(int imageId) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_resolvedKey(imageId)) ?? [];
    return list.map(int.tryParse).whereType<int>().toSet();
  }

  static Future<void> saveResolved(int imageId, Set<int> ids) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _resolvedKey(imageId),
      ids.map((e) => e.toString()).toList(),
    );
  }

  /// Carga la capa común del moodboard. Si aún no existe, importa una única
  /// vez los trazos guardados por versiones anteriores en SharedPreferences.
  ///
  /// La fila vacía también se persiste para actuar como marca de migración.
  static Future<AnnotationDocument> loadDocument({
    required AppDatabase db,
    required int projectId,
    required int imageId,
  }) async {
    final targetId = imageId.toString();
    final existing = await db.getProjectAnnotationDocument(
      projectId: projectId,
      targetType: annotationTargetType,
      targetId: targetId,
    );
    if (existing != null) {
      return AnnotationDocument.decode(existing.documentJson);
    }

    final legacy = await loadStrokes(imageId);
    final document = AnnotationDocument(
      strokes: legacy
          .where((stroke) => stroke.label == null || stroke.label == 'ARROW')
          .map(
            (stroke) => AnnotationStroke(
              id: stroke.id,
              tool: stroke.label == 'ARROW'
                  ? AnnotationToolType.arrow
                  : AnnotationToolType.pen,
              colorArgb: stroke.color.toARGB32(),
              width: stroke.width,
              points: stroke.points
                  .map((point) => AnnotationPoint(x: point.dx, y: point.dy))
                  .toList(),
            ),
          )
          .toList(),
      notes: legacy
          .where(
            (stroke) =>
                stroke.label != null &&
                stroke.label != 'ARROW' &&
                stroke.points.isNotEmpty,
          )
          .map(
            (stroke) => AnnotationNote(
              id: stroke.id,
              text: stroke.label!,
              x: stroke.points.first.dx,
              y: stroke.points.first.dy,
              width: 0.24,
              height: 0.12,
              colorArgb: stroke.color.toARGB32(),
            ),
          )
          .toList(),
    );
    await saveDocument(
      db: db,
      projectId: projectId,
      imageId: imageId,
      document: document,
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_strokesKey(imageId));
    return document;
  }

  static Future<void> saveDocument({
    required AppDatabase db,
    required int projectId,
    required int imageId,
    required AnnotationDocument document,
  }) => db.saveProjectAnnotationDocument(
    projectId: projectId,
    targetType: annotationTargetType,
    targetId: imageId.toString(),
    documentJson: document.encode(),
    documentSchemaVersion: document.schemaVersion,
  );
}
