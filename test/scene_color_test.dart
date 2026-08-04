import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iris_dp/core/utils/scene_color.dart';

void main() {
  group('buildPendingSetColorsFromScenes', () {
    test('asigna colores base distintos por localización', () {
      final colors = buildPendingSetColorsFromScenes([
        (locationSite: 'BOSQUE', shootSet: 'RÍO'),
        (locationSite: 'HOSPITAL', shootSet: 'URGENCIAS'),
        (locationSite: 'BOSQUE', shootSet: 'ENTRADA'),
      ]);

      final bosqueRio = colors['bosque|río'];
      final bosqueEntrada = colors['bosque|entrada'];
      final hospital = colors['hospital|urgencias'];

      expect(bosqueRio, isNotNull);
      expect(bosqueEntrada, isNotNull);
      expect(hospital, isNotNull);
      expect(bosqueRio, isNot(equals(hospital)));
      expect(bosqueRio, isNot(equals(bosqueEntrada)));
    });

    test('preserva colores personalizados existentes', () {
      final colors = buildPendingSetColorsFromScenes(
        [
          (locationSite: 'BOSQUE', shootSet: 'RÍO'),
          (locationSite: 'HOSPITAL', shootSet: 'URGENCIAS'),
        ],
        preserve: {'bosque|río': '#123456'},
      );

      expect(colors['bosque|río'], '#123456');
      expect(colors['hospital|urgencias'], isNot('#123456'));
    });
  });

  group('setColorKey', () {
    test('genera clave compuesta site|set', () {
      expect(setColorKey('BOSQUE', 'RÍO'), 'bosque|río');
    });
  });

  group('siteBaseHexForIndex', () {
    test('asigna hex distinto por índice de localización', () {
      final a = siteBaseHexForIndex(0);
      final b = siteBaseHexForIndex(1);
      expect(a, isNot(equals(b)));
      expect(a.startsWith('#'), isTrue);
    });

    test('normaliza hex existente como base de localización', () {
      final derived = siteBaseHexForIndex(0, existingHex: '#123456');
      expect(derived, isNot(equals(siteBaseHexForIndex(0))));
      expect(
        colorFromHex(derived),
        locationBaseColor(colorFromHex('#123456')!),
      );
    });
  });

  group('defaultSetHexForSite', () {
    test('genera variantes distintas para sets del mismo site', () {
      final set0 = defaultSetHexForSite(
        siteIndex: 0,
        setIndex: 0,
        totalSets: 3,
      );
      final set1 = defaultSetHexForSite(
        siteIndex: 0,
        setIndex: 1,
        totalSets: 3,
      );
      expect(set0, isNot(equals(set1)));
    });

    test('usa hex explícito cuando se proporciona', () {
      expect(
        defaultSetHexForSite(
          siteIndex: 0,
          setIndex: 0,
          totalSets: 1,
          explicitHex: '#ABCDEF',
        ),
        '#ABCDEF',
      );
    });
  });

  group('pendingSetColorsForSite', () {
    test('genera claves site|set ordenadas', () {
      final colors = pendingSetColorsForSite(
        locationSite: 'BOSQUE',
        setNames: ['RÍO', 'ENTRADA'],
        siteIndex: 0,
        baseHex: siteBaseHexForIndex(0),
      );
      expect(colors.keys, containsAll(['bosque|entrada', 'bosque|río']));
      expect(colors['bosque|río'], isNot(equals(colors['bosque|entrada'])));
    });
  });
}
