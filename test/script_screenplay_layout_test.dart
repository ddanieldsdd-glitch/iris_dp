import 'package:flutter_test/flutter_test.dart';
import 'package:iris_dp/features/script_import/script_screenplay_layout.dart';

void main() {
  group('ScreenplayLineClassifier', () {
    test('classifies action, character, dialogue and parenthetical', () {
      final c = ScreenplayLineClassifier();

      expect(c.classifyLine('Adil repasa el horario de los buses.', isSlugline: false),
          ScreenplayLineKind.action);
      expect(c.classifyLine('ADIL', isSlugline: false), ScreenplayLineKind.character);
      expect(c.classifyLine('Mierda.', isSlugline: false), ScreenplayLineKind.dialogue);
      expect(c.classifyLine('(susurrando)', isSlugline: false),
          ScreenplayLineKind.parenthetical);
      expect(c.classifyLine('Tranquilo.', isSlugline: false), ScreenplayLineKind.dialogue);
      expect(c.classifyLine('Karim se acerca a él.', isSlugline: false),
          ScreenplayLineKind.action);
    });

    test('recognizes character extensions', () {
      final c = ScreenplayLineClassifier();
      expect(c.classifyLine('KARIM (O.C.)', isSlugline: false),
          ScreenplayLineKind.character);
      expect(c.classifyLine('ADIL (CONT\'D)', isSlugline: false),
          ScreenplayLineKind.character);
    });
  });
}
