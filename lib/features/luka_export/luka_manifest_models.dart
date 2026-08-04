import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

const kEmbeddedLukaManifestVersion = 1;

class LukaFixtureEntry {
  final String id;
  final String label;
  final String? unrealPath;

  const LukaFixtureEntry({
    required this.id,
    required this.label,
    this.unrealPath,
  });

  factory LukaFixtureEntry.fromJson(Map<String, dynamic> json) =>
      LukaFixtureEntry(
        id: json['id'] as String,
        label: json['label'] as String,
        unrealPath: json['unrealPath'] as String?,
      );
}

class LukaCameraProfileEntry {
  final String id;
  final String label;
  final double sensorWidthMm;
  final double sensorHeightMm;
  final String? lukaPreset;

  const LukaCameraProfileEntry({
    required this.id,
    required this.label,
    required this.sensorWidthMm,
    required this.sensorHeightMm,
    this.lukaPreset,
  });

  factory LukaCameraProfileEntry.fromJson(Map<String, dynamic> json) =>
      LukaCameraProfileEntry(
        id: json['id'] as String,
        label: json['label'] as String,
        sensorWidthMm: (json['sensorWidthMm'] as num).toDouble(),
        sensorHeightMm: (json['sensorHeightMm'] as num).toDouble(),
        lukaPreset: json['lukaPreset'] as String?,
      );
}

class LukaManifest {
  final int version;
  final List<LukaFixtureEntry> fixtures;
  final List<LukaCameraProfileEntry> cameraProfiles;
  final String? notes;

  const LukaManifest({
    required this.version,
    this.fixtures = const [],
    this.cameraProfiles = const [],
    this.notes,
  });

  factory LukaManifest.fromJson(Map<String, dynamic> json) => LukaManifest(
        version: json['version'] as int? ?? 1,
        fixtures: (json['fixtures'] as List<dynamic>?)
                ?.map((e) =>
                    LukaFixtureEntry.fromJson(Map<String, dynamic>.from(e as Map)))
                .toList() ??
            const [],
        cameraProfiles: (json['cameraProfiles'] as List<dynamic>?)
                ?.map((e) => LukaCameraProfileEntry.fromJson(
                    Map<String, dynamic>.from(e as Map)))
                .toList() ??
            const [],
        notes: json['notes'] as String?,
      );

  bool hasFixture(String? id) =>
      id != null && fixtures.any((f) => f.id == id);

  LukaFixtureEntry? fixture(String? id) {
    if (id == null) return null;
    for (final f in fixtures) {
      if (f.id == id) return f;
    }
    return null;
  }
}

Future<LukaManifest> loadEmbeddedLukaManifest() async {
  try {
    final raw = await rootBundle.loadString('assets/luka/manifest.json');
    return LukaManifest.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  } catch (_) {
    return const LukaManifest(version: kEmbeddedLukaManifestVersion);
  }
}
