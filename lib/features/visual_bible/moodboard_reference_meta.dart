import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../core/database/app_database.dart';

/// INT/EXT alineado con guion literario / técnico (`Scenes.intExt`).
const kMoodboardIntExt = <String>['INT', 'EXT', 'INT/EXT'];

/// Looks de luz (calidad / intención).
const kMoodboardLightingLooks = <String>[
  'Suave',
  'Dura',
  'Prácticos',
  'Disponible',
  'Motivada',
  'Contraluz',
  'Baja clave',
  'Alta clave',
];

/// Fuentes de luz (tipo).
const kMoodboardLightSources = <String>[
  'Natural',
  'Tungsteno',
  'HMI',
  'LED',
  'Mixto',
];

/// Textura de la luz.
const kMoodboardLightTextures = <String>[
  'Difusa',
  'Especular',
  'Rota',
  'Motorizada',
  'Humo / niebla',
  'Rebote',
  'Proyectada',
];

/// Composición del plano.
const kMoodboardCompositions = <String>[
  'Regla de tercios',
  'Centrado',
  'Simétrico',
  'Perfil',
  'Sobrehombro',
  'Espacio negativo',
  'Bajo ángulo',
  'Alto ángulo',
  'Dutch / inclinado',
  'Marco en marco',
];

/// Momento del día alineado con `Scenes.dayNight`.
const kMoodboardTimesOfDay = <String>[
  'DÍA',
  'NOCHE',
  'AMANECER',
  'ATARDECER',
  'HORA AZUL',
];

const kMoodboardColorMoods = <String>[
  'Fría',
  'Cálida',
  'Desaturada',
  'Saturada',
  'Monocroma',
  'Teal & orange',
  'Natural',
];

/// Metadatos cinematográficos de una still del moodboard (local + editable).
class MoodboardReferenceMeta {
  final String? title;
  final String? year;
  final String? director;
  final String? dop;
  final String? aspectRatio;
  final String? camera;
  final String? lenses;
  /// Apunte principal del plano (hover + detalle).
  final String? technicalNotes;
  final List<String> paletteHex;
  final List<String> tags;

  /// Catálogo biblia.
  final String? lightingLook;
  final String? lightSource;
  final String? lightTexture;
  final String? composition;
  /// INT / EXT / INT-EXT (guion).
  final String? locationKind;
  /// Nombre del set vinculado (espejo de Drift linkedLocationName).
  final String? locationName;
  final String? timeOfDay;
  final String? colorMood;
  final bool pendingReview;

  const MoodboardReferenceMeta({
    this.title,
    this.year,
    this.director,
    this.dop,
    this.aspectRatio,
    this.camera,
    this.lenses,
    this.technicalNotes,
    this.paletteHex = const [],
    this.tags = const [],
    this.lightingLook,
    this.lightSource,
    this.lightTexture,
    this.composition,
    this.locationKind,
    this.locationName,
    this.timeOfDay,
    this.colorMood,
    this.pendingReview = false,
  });

  MoodboardReferenceMeta copyWith({
    String? title,
    String? year,
    String? director,
    String? dop,
    String? aspectRatio,
    String? camera,
    String? lenses,
    String? technicalNotes,
    List<String>? paletteHex,
    List<String>? tags,
    String? lightingLook,
    String? lightSource,
    String? lightTexture,
    String? composition,
    String? locationKind,
    String? locationName,
    String? timeOfDay,
    String? colorMood,
    bool? pendingReview,
  }) {
    return MoodboardReferenceMeta(
      title: title ?? this.title,
      year: year ?? this.year,
      director: director ?? this.director,
      dop: dop ?? this.dop,
      aspectRatio: aspectRatio ?? this.aspectRatio,
      camera: camera ?? this.camera,
      lenses: lenses ?? this.lenses,
      technicalNotes: technicalNotes ?? this.technicalNotes,
      paletteHex: paletteHex ?? this.paletteHex,
      tags: tags ?? this.tags,
      lightingLook: lightingLook ?? this.lightingLook,
      lightSource: lightSource ?? this.lightSource,
      lightTexture: lightTexture ?? this.lightTexture,
      composition: composition ?? this.composition,
      locationKind: locationKind ?? this.locationKind,
      locationName: locationName ?? this.locationName,
      timeOfDay: timeOfDay ?? this.timeOfDay,
      colorMood: colorMood ?? this.colorMood,
      pendingReview: pendingReview ?? this.pendingReview,
    );
  }

  Map<String, dynamic> toJson() => {
        if (title != null) 'title': title,
        if (year != null) 'year': year,
        if (director != null) 'director': director,
        if (dop != null) 'dop': dop,
        if (aspectRatio != null) 'aspectRatio': aspectRatio,
        if (camera != null) 'camera': camera,
        if (lenses != null) 'lenses': lenses,
        if (technicalNotes != null) 'technicalNotes': technicalNotes,
        if (paletteHex.isNotEmpty) 'paletteHex': paletteHex,
        if (tags.isNotEmpty) 'tags': tags,
        if (lightingLook != null) 'lightingLook': lightingLook,
        if (lightSource != null) 'lightSource': lightSource,
        if (lightTexture != null) 'lightTexture': lightTexture,
        if (composition != null) 'composition': composition,
        if (locationKind != null) 'locationKind': locationKind,
        if (locationName != null) 'locationName': locationName,
        if (timeOfDay != null) 'timeOfDay': timeOfDay,
        if (colorMood != null) 'colorMood': colorMood,
        if (pendingReview) 'pendingReview': true,
      };

  factory MoodboardReferenceMeta.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const MoodboardReferenceMeta();
    return MoodboardReferenceMeta(
      title: json['title'] as String?,
      year: json['year'] as String?,
      director: json['director'] as String?,
      dop: json['dop'] as String?,
      aspectRatio: json['aspectRatio'] as String?,
      camera: json['camera'] as String?,
      lenses: json['lenses'] as String?,
      technicalNotes: json['technicalNotes'] as String?,
      paletteHex: (json['paletteHex'] as List?)
              ?.whereType<String>()
              .toList() ??
          const [],
      tags: (json['tags'] as List?)?.whereType<String>().toList() ?? const [],
      lightingLook: json['lightingLook'] as String?,
      lightSource: json['lightSource'] as String?,
      lightTexture: json['lightTexture'] as String?,
      composition: json['composition'] as String?,
      locationKind: json['locationKind'] as String?,
      locationName: json['locationName'] as String?,
      timeOfDay: json['timeOfDay'] as String?,
      colorMood: json['colorMood'] as String?,
      pendingReview: json['pendingReview'] == true,
    );
  }

  bool get isEmpty =>
      (title == null || title!.trim().isEmpty) &&
      (year == null || year!.trim().isEmpty) &&
      (director == null || director!.trim().isEmpty) &&
      (dop == null || dop!.trim().isEmpty) &&
      (aspectRatio == null || aspectRatio!.trim().isEmpty) &&
      (camera == null || camera!.trim().isEmpty) &&
      (lenses == null || lenses!.trim().isEmpty) &&
      (technicalNotes == null || technicalNotes!.trim().isEmpty) &&
      paletteHex.isEmpty &&
      tags.isEmpty &&
      (lightingLook == null || lightingLook!.trim().isEmpty) &&
      (lightSource == null || lightSource!.trim().isEmpty) &&
      (lightTexture == null || lightTexture!.trim().isEmpty) &&
      (composition == null || composition!.trim().isEmpty) &&
      (locationKind == null || locationKind!.trim().isEmpty) &&
      (locationName == null || locationName!.trim().isEmpty) &&
      (timeOfDay == null || timeOfDay!.trim().isEmpty) &&
      (colorMood == null || colorMood!.trim().isEmpty) &&
      !pendingReview;

  String get searchBlob => [
        title,
        year,
        director,
        dop,
        aspectRatio,
        camera,
        lenses,
        technicalNotes,
        lightingLook,
        lightSource,
        lightTexture,
        composition,
        locationKind,
        locationName,
        timeOfDay,
        colorMood,
        ...tags,
      ].whereType<String>().join(' ').toLowerCase();

  String? get primaryNote {
    final n = technicalNotes?.trim();
    if (n != null && n.isNotEmpty) return n;
    return null;
  }

  /// Líneas compactas para export PDF (tags + facetas + notas).
  /// Máximo 2 líneas para no saturar la celda del moodboard.
  List<String> get exportDetailLines {
    final facets = <String>[
      if (tags.isNotEmpty) tags.join(' · '),
      if (_trimOrNull(lightingLook) case final v?) v,
      if (_trimOrNull(lightSource) case final v?) v,
      if (_trimOrNull(lightTexture) case final v?) v,
      if (_trimOrNull(composition) case final v?) v,
      if (_trimOrNull(colorMood) case final v?) v,
      if (_trimOrNull(timeOfDay) case final v?) v,
      if (_trimOrNull(locationKind) case final v?) v,
    ];
    final lines = <String>[];
    if (facets.isNotEmpty) {
      lines.add(facets.take(4).join(' · '));
    }
    final note = primaryNote;
    if (note != null) lines.add(note);
    return lines;
  }

  static String? _trimOrNull(String? value) {
    final t = value?.trim();
    if (t == null || t.isEmpty) return null;
    return t;
  }
}

/// Persistencia local de meta por imagen (Drift + migración lazy desde SharedPreferences).
abstract final class MoodboardReferenceMetaStore {
  static String _legacyKey(int imageId) => 'moodboard_ref_meta_$imageId';

  static MoodboardReferenceMeta? _metaFromRaw(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      return MoodboardReferenceMeta.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    } catch (_) {
      return null;
    }
  }

  static Future<MoodboardReferenceMeta> _loadFromLegacyPrefs(int imageId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_legacyKey(imageId));
    if (raw == null || raw.isEmpty) return const MoodboardReferenceMeta();
    try {
      return MoodboardReferenceMeta.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    } catch (_) {
      return const MoodboardReferenceMeta();
    }
  }

  static Future<MoodboardReferenceMeta> load(
    AppDatabase db,
    int imageId,
  ) async {
    final fromDb = await db.getMoodboardImageMeta(imageId);
    if (fromDb != null) {
      return MoodboardReferenceMeta.fromJson(fromDb);
    }

    final legacy = await _loadFromLegacyPrefs(imageId);
    if (!legacy.isEmpty) {
      await db.saveMoodboardImageMeta(imageId, legacy.toJson());
      return legacy;
    }

    return const MoodboardReferenceMeta();
  }

  static Future<void> save(
    AppDatabase db,
    int imageId,
    MoodboardReferenceMeta meta,
  ) async {
    if (meta.isEmpty) {
      await db.saveMoodboardImageMeta(imageId, null);
      return;
    }
    await db.saveMoodboardImageMeta(imageId, meta.toJson());
  }

  static Future<Map<int, MoodboardReferenceMeta>> loadMany(
    AppDatabase db,
    Iterable<int> ids,
  ) async {
    final idList = ids.toList();
    if (idList.isEmpty) return {};

    final rows = await (db.select(db.moodboardImages)
          ..where((m) => m.id.isIn(idList)))
        .get();
    final out = <int, MoodboardReferenceMeta>{};

    for (final row in rows) {
      final fromColumn = _metaFromRaw(row.metaJson);
      if (fromColumn != null && !fromColumn.isEmpty) {
        out[row.id] = fromColumn;
        continue;
      }

      final legacy = await _loadFromLegacyPrefs(row.id);
      if (!legacy.isEmpty) {
        await db.saveMoodboardImageMeta(row.id, legacy.toJson());
        out[row.id] = legacy;
      }
    }

    return out;
  }
}
