import 'package:flutter_test/flutter_test.dart';
import 'package:iris_dp/shared/visual_bible/bible_lighting_data.dart';

void main() {
  test('migrate moves visualIntent to narrativeStory', () {
    final out = BibleLightingData.migrate({
      'visualIntent': 'La luz cuenta la soledad',
    });
    expect(out['narrativeStory'], 'La luz cuenta la soledad');
  });

  test('migrate moves global behaviorCards to textureCards', () {
    final out = BibleLightingData.migrate({
      'behaviorCards': [
        {'title': 'Haze', 'meta': 'Soft'},
      ],
    });
    expect(out['textureCards'], isA<List>());
    expect((out['textureCards'] as List).length, 1);
  });

  test('migrate moves root telemetry to byPlan when selectedPlanId set', () {
    final out = BibleLightingData.migrate({
      'selectedPlanId': 42,
      'colorTemp': 3200,
      'activeFixtures': [
        {'id': 'K1', 'name': 'Skypanel'},
      ],
    });
    final plan = BibleLightingData.planFor(out, 42);
    expect(plan['colorTemp'], 3200);
    expect(plan['activeFixtures'], isA<List>());
  });

  test('mergePlan updates byPlan slot', () {
    final merged = BibleLightingData.mergePlan({}, 7, {
      'lightBehavior': 'Prácticos ventana',
    });
    expect(BibleLightingData.planFor(merged, 7)['lightBehavior'],
        'Prácticos ventana');
    expect(merged['selectedPlanId'], 7);
  });
}
