import 'package:flutter_test/flutter_test.dart';
import 'package:iris_dp/features/visual_bible/moodboard_reference_meta.dart';

void main() {
  group('MoodboardReferenceMeta.exportDetailLines', () {
    test('compacta tags, facetas y nota técnica', () {
      const meta = MoodboardReferenceMeta(
        tags: ['neon', 'night'],
        lightingLook: 'Dura',
        composition: 'Centrado',
        colorMood: 'Fría',
        timeOfDay: 'NOCHE',
        technicalNotes: 'Key lateral dura',
      );

      expect(meta.exportDetailLines, [
        'neon · night · Dura · Centrado · Fría',
        'Key lateral dura',
      ]);
    });

    test('vacío si no hay meta útil', () {
      expect(const MoodboardReferenceMeta().exportDetailLines, isEmpty);
    });
  });
}
