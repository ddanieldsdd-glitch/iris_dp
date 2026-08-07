import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
    final pts = (json['points'] as List?)
            ?.map((e) {
              final a = e as List;
              return Offset(
                (a[0] as num).toDouble(),
                (a[1] as num).toDouble(),
              );
            })
            .toList() ??
        <Offset>[];
    final colorInt = json['color'] as int? ?? 0xFF2997FF;
    return MoodboardStroke(
      id: json['id'] as String? ??
          DateTime.now().microsecondsSinceEpoch.toString(),
      color: Color(colorInt),
      width: (json['width'] as num?)?.toDouble() ?? 3,
      points: pts,
      label: json['label'] as String?,
    );
  }
}

abstract final class MoodboardAnnotationStore {
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
}
