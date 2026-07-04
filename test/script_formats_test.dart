import 'package:flutter_test/flutter_test.dart';
import 'package:iris_dp/features/script_import/script_parser.dart';

void main() {
  group('ScriptParser extended formats', () {
    test('detects Spanish dot sluglines (Muy Lejos)', () {
      const script = '''
EXT. BOSQUE. DÍA.
Action line.

INT. DORMITORIO. DÍA.
More action.

INT. TEATRO. DÍA.
''';

      final sluglines = ScriptParser.parse(script);
      expect(sluglines.length, 3);
      expect(sluglines[0].location, 'BOSQUE');
      expect(sluglines[0].dayNight, 'DÍA');
      expect(sluglines[1].location, 'DORMITORIO');
    });

    test('merges multiline sluglines split by em dash (Presidium)', () {
      const script = '''
INT. HOTEL ROOM
–

NIGHT

Action starts here.
''';

      final sluglines = ScriptParser.parse(script);
      expect(sluglines.length, 1);
      expect(sluglines[0].intExt, 'INT');
      expect(sluglines[0].location, 'HOTEL ROOM');
      expect(sluglines[0].dayNight, 'NOCHE');
    });
  });
}
