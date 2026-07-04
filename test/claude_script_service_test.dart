import 'package:flutter_test/flutter_test.dart';
import 'package:iris_dp/features/script_import/claude_script_service.dart';
import 'package:iris_dp/features/script_import/script_parser.dart';

void main() {
  group('ClaudeScriptService.extractJsonFromResponse', () {
    test('extrae JSON de bloque markdown', () {
      const input = '''```json
[{"number": 1, "intExt": "INT", "dayNight": "DÍA", "location": "COCINA", "shootSet": "COCINA", "locationSite": "CASA"}]
```''';

      final json = ClaudeScriptService.extractJsonFromResponse(input);
      expect(json.startsWith('['), isTrue);
      expect(json.contains('"COCINA"'), isTrue);
    });

    test('extrae JSON sin markdown', () {
      const input =
          'Aquí va: [{"number": 2, "intExt": "EXT", "dayNight": "NOCHE", "location": "CALLE", "shootSet": "CALLE", "locationSite": "PUEBLO"}] fin';

      final json = ClaudeScriptService.extractJsonFromResponse(input);
      expect(json.startsWith('['), isTrue);
      expect(json.endsWith(']'), isTrue);
    });
  });

  group('NormalizedScene.mergeWithRaw', () {
    test('conserva escenas del parser si la IA devuelve menos', () {
      final raw = [
        RawSlugline(
          number: 1,
          intExt: 'INT',
          dayNight: 'DÍA',
          location: 'A',
          rawLine: 'INT. A - DÍA',
          startIndex: 0,
        ),
        RawSlugline(
          number: 2,
          intExt: 'EXT',
          dayNight: 'NOCHE',
          location: 'B',
          rawLine: 'EXT. B - NOCHE',
          startIndex: 20,
        ),
      ];

      final ai = [
        NormalizedScene(
          number: 1,
          intExt: 'INT',
          dayNight: 'DÍA',
          location: 'A MEJORADA',
          shootSet: 'A',
          locationSite: 'SITIO',
        ),
      ];

      final merged = NormalizedScene.mergeWithRaw(raw, ai);
      expect(merged.length, 2);
      expect(merged[0].location, 'A MEJORADA');
      expect(merged[1].location, 'B');
    });
  });
}
