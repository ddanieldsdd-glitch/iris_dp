import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

/// Un modo de grabación de una cámara, tal como lo da el catálogo.
class CameraModeFacts {
  final String name;
  final double? widthMm;
  final double? heightMm;
  final int? widthPx;
  final int? heightPx;
  final String? aspectRatio;

  /// Parte del ancho del sensor que usa el modo: 1 = todo el sensor.
  final double? cropFactor;
  final String? codec;
  final double? fpsMax;

  const CameraModeFacts({
    required this.name,
    this.widthMm,
    this.heightMm,
    this.widthPx,
    this.heightPx,
    this.aspectRatio,
    this.cropFactor,
    this.codec,
    this.fpsMax,
  });

  factory CameraModeFacts.fromJson(Map<dynamic, dynamic> json) {
    double? d(Object? v) => v is num ? v.toDouble() : null;
    String? s(Object? v) {
      final text = v?.toString().trim() ?? '';
      return text.isEmpty ? null : text;
    }

    return CameraModeFacts(
      name: json['name']?.toString() ?? '',
      widthMm: d(json['widthMm']),
      heightMm: d(json['heightMm']),
      widthPx: (json['maxWidthPx'] as num?)?.round(),
      heightPx: (json['maxHeightPx'] as num?)?.round(),
      aspectRatio: s(json['aspectRatio']),
      cropFactor: d(json['cropFactor']),
      codec: s(json['codec']),
      fpsMax: d(json['fpsMax']),
    );
  }

  String? get resolution =>
      widthPx == null || heightPx == null ? null : '$widthPx × $heightPx';

  String? get sensorArea => widthMm == null || heightMm == null
      ? null
      : '${_n(widthMm!)} × ${_n(heightMm!)} mm';

  String? get fpsLabel => fpsMax == null ? null : '${_n(fpsMax!)} fps';

  /// El modo no usa todo el sensor.
  bool get crops => cropFactor != null && cropFactor! < 0.985;

  /// «Usa el 89 % del ancho del sensor: un 35 mm encuadra como un 39 mm».
  String? cropWarning({double sampleFocal = 35}) {
    if (!crops) return null;
    final percent = (cropFactor! * 100).round();
    final equivalent = (sampleFocal / cropFactor!).round();
    return 'Este modo usa el $percent % del ancho del sensor: un '
        '${_n(sampleFocal)} mm encuadra como un $equivalent mm.';
  }

  static String _n(double v) =>
      v.toStringAsFixed(v % 1 == 0 ? 0 : (v * 10 % 1 == 0 ? 1 : 2));
}

/// Lo que el catálogo sabe de una cámara. Lo que no sabe es nulo o vacío:
/// la pantalla dice «sin dato en el catálogo», no lo inventa.
class CameraFacts {
  final String name;
  final double? sensorWidthMm;
  final double? sensorHeightMm;
  final String? mount;
  final double? dynamicRangeStops;
  final int? nativeIso;
  final String? logFormats;
  final String? sensorType;
  final double? weightKg;
  final List<CameraModeFacts> modes;

  const CameraFacts({
    required this.name,
    this.sensorWidthMm,
    this.sensorHeightMm,
    this.mount,
    this.dynamicRangeStops,
    this.nativeIso,
    this.logFormats,
    this.sensorType,
    this.weightKg,
    this.modes = const [],
  });

  static String? _s(Object? v) {
    final text = v?.toString().trim() ?? '';
    return text.isEmpty ? null : text;
  }

  /// De la entrada del catálogo embebido.
  factory CameraFacts.fromCatalog(Map<dynamic, dynamic> json) => CameraFacts(
    name: '${json['brand'] ?? ''} ${json['model'] ?? ''}'.trim(),
    sensorWidthMm: (json['sensorWidthMm'] as num?)?.toDouble(),
    sensorHeightMm: (json['sensorHeightMm'] as num?)?.toDouble(),
    mount: _s(json['mountType']),
    dynamicRangeStops: (json['dynamicRangeStops'] as num?)?.toDouble(),
    nativeIso: (json['nativeIso'] as num?)?.round(),
    logFormats: _s(json['logFormats']),
    sensorType: _s(json['colorScience']),
    weightKg: (json['weightKg'] as num?)?.toDouble(),
    modes: [
      if (json['sensorModes'] is List)
        for (final m in json['sensorModes'] as List)
          if (m is Map) CameraModeFacts.fromJson(m),
    ],
  );

  /// Con los datos de [other] donde este no los tiene. Los modos se unen
  /// por nombre: lo que falte en uno (códec, fps) lo pone el otro.
  CameraFacts mergedWith(CameraFacts? other) {
    if (other == null) return this;
    final byName = {for (final m in other.modes) m.name.toLowerCase(): m};
    final merged = [
      for (final m in modes)
        () {
          final o = byName.remove(m.name.toLowerCase());
          if (o == null) return m;
          return CameraModeFacts(
            name: m.name,
            widthMm: m.widthMm ?? o.widthMm,
            heightMm: m.heightMm ?? o.heightMm,
            widthPx: m.widthPx ?? o.widthPx,
            heightPx: m.heightPx ?? o.heightPx,
            aspectRatio: m.aspectRatio ?? o.aspectRatio,
            cropFactor: m.cropFactor ?? o.cropFactor,
            codec: m.codec ?? o.codec,
            fpsMax: m.fpsMax ?? o.fpsMax,
          );
        }(),
      ...byName.values,
    ];
    return CameraFacts(
      name: name.isNotEmpty ? name : other.name,
      sensorWidthMm: sensorWidthMm ?? other.sensorWidthMm,
      sensorHeightMm: sensorHeightMm ?? other.sensorHeightMm,
      mount: mount ?? other.mount,
      dynamicRangeStops: dynamicRangeStops ?? other.dynamicRangeStops,
      nativeIso: nativeIso ?? other.nativeIso,
      logFormats: logFormats ?? other.logFormats,
      sensorType: sensorType ?? other.sensorType,
      weightKg: weightKg ?? other.weightKg,
      modes: merged,
    );
  }

  static String _n(double v) => v.toStringAsFixed(v % 1 == 0 ? 0 : 2);

  /// Ficha del cuerpo, con los rótulos de la biblia. Solo lo que se sabe.
  Map<String, String> get bodyFacts => {
    if (sensorWidthMm != null && sensorHeightMm != null)
      'Sensor': '${_n(sensorWidthMm!)}×${_n(sensorHeightMm!)} mm',
    if (sensorType != null) 'Tipo de sensor': sensorType!,
    if (mount != null) 'Montura': mount!,
    if (dynamicRangeStops != null)
      'Rango dinámico': '${_n(dynamicRangeStops!)} stops',
    if (nativeIso != null) 'ISO nativo': '$nativeIso',
    if (logFormats != null) 'Curva log': logFormats!,
    if (weightKg != null) 'Peso del cuerpo': '${_n(weightKg!)} kg',
  };

  CameraModeFacts? mode(String? name) {
    final wanted = name?.trim().toLowerCase() ?? '';
    if (wanted.isEmpty) return null;
    for (final m in modes) {
      if (m.name.toLowerCase() == wanted) return m;
    }
    return null;
  }

  /// Modos que llegan a [fps], del que más sensor usa al que menos.
  List<CameraModeFacts> modesReaching(double fps) => [
    for (final m in modes)
      if (m.fpsMax != null && m.fpsMax! >= fps) m,
  ]..sort((a, b) => (b.cropFactor ?? 0).compareTo(a.cropFactor ?? 0));
}

/// Primer número de un texto: «48 fps» → 48.
double? firstNumber(String text) {
  final match = RegExp(r'\d+(?:[.,]\d+)?').firstMatch(text);
  return match == null
      ? null
      : double.tryParse(match.group(0)!.replaceAll(',', '.'));
}

/// El catálogo de material que viene con la app. Se lee una vez.
///
/// La base del usuario puede ir por detrás (no trae el códec ni los fps
/// de cada modo, ni el peso de las lentes): aquí están si el Excel los
/// tiene.
abstract final class EquipmentCatalog {
  static Map<String, Map<String, dynamic>>? _cameras;
  static Map<String, Map<String, dynamic>>? _lenses;

  static Map<String, Map<String, dynamic>> _index(String raw) {
    final decoded = jsonDecode(raw);
    final list = decoded is List
        ? decoded
        : (decoded is Map
              ? (decoded['cameras'] ?? decoded['lenses'] ?? decoded['items'])
              : null);
    return {
      if (list is List)
        for (final e in list)
          if (e is Map && e['externalId'] != null)
            e['externalId'].toString(): Map<String, dynamic>.from(e),
    };
  }

  static Future<void> _load() async {
    _cameras ??= _index(
      await rootBundle.loadString('assets/catalog/cameras.json'),
    );
    _lenses ??= _index(
      await rootBundle.loadString('assets/catalog/lenses.json'),
    );
  }

  static String _key(String brand, String model) =>
      '$brand $model'.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

  /// La cámara del catálogo por su identificador o, si no lo tiene (una
  /// duplicada, una creada a mano con el mismo nombre), por marca y modelo.
  static Future<CameraFacts?> camera({
    String? externalId,
    String brand = '',
    String model = '',
  }) async {
    await _load();
    final byId = externalId == null ? null : _cameras![externalId];
    if (byId != null) return CameraFacts.fromCatalog(byId);
    final wanted = _key(brand, model);
    if (wanted.isEmpty) return null;
    for (final entry in _cameras!.values) {
      if (_key('${entry['brand']}', '${entry['model']}') == wanted) {
        return CameraFacts.fromCatalog(entry);
      }
    }
    return null;
  }

  /// Peso de una lente, en kilos, o nulo si el catálogo no lo tiene.
  static Future<double?> lensWeightKg(String? externalId) async {
    await _load();
    return (_lenses![externalId]?['weightKg'] as num?)?.toDouble();
  }
}
