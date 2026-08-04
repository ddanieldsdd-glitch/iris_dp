import 'package:flutter_test/flutter_test.dart';
import 'package:iris_dp/core/utils/character_colors.dart';

void main() {
  group('characterColorKey', () {
    test('normaliza a mayúsculas', () {
      expect(characterColorKey('  gala  '), 'GALA');
    });
  });

  group('decodeCharacterColors / encodeCharacterColors', () {
    test('codifica y decodifica mapa de colores', () {
      final encoded = encodeCharacterColors({
        'GALA': '#E63946',
        'Karim': '#2A9D8F',
      });
      expect(encoded, isNotNull);

      final decoded = decodeCharacterColors(encoded);
      expect(decoded['GALA'], '#E63946');
      expect(decoded['KARIM'], '#2A9D8F');
    });

    test('devuelve mapa vacío con json inválido', () {
      expect(decodeCharacterColors('{bad'), isEmpty);
    });
  });

  group('buildDefaultCharacterColors', () {
    test('asigna colores distintos a personajes nuevos', () {
      final colors = buildDefaultCharacterColors(['GALA', 'KARIM']);
      expect(colors['GALA'], isNotNull);
      expect(colors['KARIM'], isNotNull);
      expect(colors['GALA'], isNot(equals(colors['KARIM'])));
    });

    test('preserva colores existentes', () {
      final colors = buildDefaultCharacterColors(
        ['GALA', 'KARIM'],
        preserve: {'GALA': '#123456'},
      );
      expect(colors['GALA'], '#123456');
      expect(colors['KARIM'], isNot('#123456'));
    });
  });
}
