import 'dart:convert';
import 'package:http/http.dart' as http;
import 'script_parser.dart';

class ClaudeScriptService {
  static const _apiUrl = 'https://api.anthropic.com/v1/messages';
  static const defaultTimeout = Duration(seconds: 90);

  final String apiKey;
  final Duration timeout;

  ClaudeScriptService(this.apiKey, {this.timeout = defaultTimeout});

  Future<List<NormalizedScene>> normalizeSluglines(
    List<RawSlugline> sluglines,
  ) async {
    final sluglinesJson = jsonEncode(sluglines.map((s) => s.toJson()).toList());

    final response = await http
        .post(
          Uri.parse(_apiUrl),
          headers: {
            'x-api-key': apiKey,
            'anthropic-version': '2023-06-01',
            'content-type': 'application/json',
          },
          body: jsonEncode({
            'model': 'claude-sonnet-4-6',
            'max_tokens': 4096,
            'messages': [
              {
                'role': 'user',
                'content': '''Eres un asistente de producción cinematográfica.
Analiza estas sluglines de un guion y devuelve ÚNICAMENTE un JSON válido, sin texto adicional.

Sluglines:
$sluglinesJson

Para cada escena devuelve:
- number: número de escena (int)
- intExt: "INT", "EXT" o "INT/EXT"
- dayNight: "DÍA", "NOCHE", "AMANECER" o "ATARDECER"  
- location: nombre de la localización exacta del guion
- locationSite: localización amplia de rodaje (ej. "BOSQUE" agrupa varios sets)
- shootSet: set concreto dentro de esa localización (ej. "RÍO", "ENTRADA DEL BOSQUE")

Devuelve solo el array JSON, sin markdown ni explicaciones.'''
              }
            ],
          }),
        )
        .timeout(timeout);

    if (response.statusCode != 200) {
      final body = response.body.length > 200
          ? '${response.body.substring(0, 200)}...'
          : response.body;
      throw Exception(
        'Claude API error: ${response.statusCode}${body.isNotEmpty ? ' — $body' : ''}',
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final text = (data['content'] as List)
        .whereType<Map>()
        .where((b) => b['type'] == 'text')
        .map((b) => b['text'] as String)
        .join();

    final List<dynamic> jsonList =
        jsonDecode(extractJsonFromResponse(text)) as List<dynamic>;
    final normalized = jsonList
        .map((j) => NormalizedScene.fromJson(j as Map<String, dynamic>))
        .toList();
    return NormalizedScene.mergeWithRaw(sluglines, normalized);
  }

  /// Extrae un array JSON de la respuesta de Claude (público para tests).
  static String extractJsonFromResponse(String text) {
    var cleaned = text.trim();
    if (cleaned.startsWith('```')) {
      cleaned = cleaned.replaceFirst(RegExp(r'^```(?:json)?\s*'), '');
      cleaned = cleaned.replaceFirst(RegExp(r'\s*```$'), '');
    }
    final start = cleaned.indexOf('[');
    final end = cleaned.lastIndexOf(']');
    if (start >= 0 && end > start) {
      return cleaned.substring(start, end + 1);
    }
    return cleaned;
  }
}

class NormalizedScene {
  final int number;
  final String intExt;
  final String dayNight;
  final String location;
  final String shootSet;
  final String locationSite;
  final String? description;
  final String? locationColor;

  const NormalizedScene({
    required this.number,
    required this.intExt,
    required this.dayNight,
    required this.location,
    required this.shootSet,
    required this.locationSite,
    this.description,
    this.locationColor,
  });

  factory NormalizedScene.fromJson(Map<String, dynamic> j) => NormalizedScene(
        number: (j['number'] as num).toInt(),
        intExt: j['intExt'] as String,
        dayNight: j['dayNight'] as String,
        location: j['location'] as String,
        shootSet: (j['shootSet'] ?? j['locationGroup']) as String,
        locationSite: (j['locationSite'] ?? j['shootSet'] ?? j['locationGroup']) as String,
        description: j['description'] as String?,
        locationColor: j['locationColor'] as String?,
      );

  factory NormalizedScene.fromRaw(RawSlugline raw) => NormalizedScene(
        number: raw.number,
        intExt: raw.intExt,
        dayNight: raw.dayNight,
        location: raw.location,
        shootSet: raw.location,
        locationSite: raw.location,
      );

  NormalizedScene copyWith({
    int? number,
    String? intExt,
    String? dayNight,
    String? location,
    String? shootSet,
    String? locationSite,
    String? description,
    String? locationColor,
  }) =>
      NormalizedScene(
        number: number ?? this.number,
        intExt: intExt ?? this.intExt,
        dayNight: dayNight ?? this.dayNight,
        location: location ?? this.location,
        shootSet: shootSet ?? this.shootSet,
        locationSite: locationSite ?? this.locationSite,
        description: description ?? this.description,
        locationColor: locationColor ?? this.locationColor,
      );

  static List<NormalizedScene> mergeWithRaw(
    List<RawSlugline> raw,
    List<NormalizedScene> ai,
  ) {
    if (ai.isEmpty) return raw.map(NormalizedScene.fromRaw).toList();

    final byNumber = {for (final s in ai) s.number: s};
    return raw.map((r) {
      final match = byNumber[r.number];
      if (match != null) return match;
      return NormalizedScene.fromRaw(r);
    }).toList();
  }
}
