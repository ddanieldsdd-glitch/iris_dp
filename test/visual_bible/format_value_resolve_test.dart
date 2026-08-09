import 'package:flutter_test/flutter_test.dart';
import 'package:iris_dp/shared/visual_bible/bible_section_value_resolve.dart';

void main() {
  group('BibleSectionValueResolve.resolveSectionString', () {
    test('solo legacy cuando falta clave canónica', () {
      expect(
        BibleSectionValueResolve.resolveSectionString(
          const {},
          'activeRatio',
          legacy: '2.39:1',
        ),
        '2.39:1',
      );
    });

    test('solo formatData cuando blob tiene clave', () {
      expect(
        BibleSectionValueResolve.resolveSectionString(
          const {'resolution': '4.6K'},
          'resolution',
          legacy: '1080p',
        ),
        '4.6K',
      );
    });

    test('ambos iguales devuelve blob', () {
      expect(
        BibleSectionValueResolve.resolveSectionString(
          const {'activeRatio': '1.85:1'},
          'activeRatio',
          legacy: '1.85:1',
        ),
        '1.85:1',
      );
    });

    test('ambos distintos gana blob', () {
      expect(
        BibleSectionValueResolve.resolveSectionString(
          const {'activeRatio': '2.39:1'},
          'activeRatio',
          legacy: '1.85:1',
        ),
        '2.39:1',
      );
    });

    test('blob vacío no cae a legacy', () {
      expect(
        BibleSectionValueResolve.resolveSectionString(
          const {'intentNarrative': ''},
          'intentNarrative',
          legacyFallbacks: ['Narrativa legacy'],
        ),
        '',
      );
    });

    test('narrativa usa legacyFallbacks en orden', () {
      expect(
        BibleSectionValueResolve.resolveSectionString(
          const {},
          'intentNarrative',
          legacyFallbacks: [null, '', 'Justificación'],
        ),
        'Justificación',
      );
    });
  });
}
