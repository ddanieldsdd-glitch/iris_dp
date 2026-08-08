import 'package:flutter_test/flutter_test.dart';
import 'package:iris_dp/core/database/app_database.dart';
import 'package:iris_dp/shared/visual_bible/bible_optics_context.dart';

void main() {
  test('resolve spherical when no anamorphic signals', () {
    final ctx = BibleOpticsContext.resolve(
      opticType: 'Spherical',
      formatData: {'squeezeFactor': '1.0x'},
    );
    expect(ctx.isAnamorphic, isFalse);
    expect(ctx.squeezeRatio, 1.0);
  });

  test('resolve anamorphic from lens catalog', () {
    final lens = Lense(
      id: 1,
      brand: 'Cooke',
      model: 'Anamorphic',
      focalLength: 32,
      minTStop: 2.8,
      formatCoverage: 'S35',
      mountType: 'PL',
      isAnamorphic: true,
      squeezeRatio: 2.0,
      isCustom: false,
      vintage: false,
      lukaCompatible: false,
    );
    final ctx = BibleOpticsContext.resolve(primaryLens: lens);
    expect(ctx.isAnamorphic, isTrue);
    expect(ctx.squeezeRatio, 2.0);
  });

  test('lensSetsFromJson parses mixed sets', () {
    const raw =
        '{"lensSets":[{"name":"A-Cam","isAnamorphic":true,"squeezeRatio":2.0}]}';
    final sets = BibleOpticsContext.lensSetsFromJson(raw);
    expect(sets.length, 1);
    expect(sets.first['name'], 'A-Cam');
    expect(sets.first['isAnamorphic'], isTrue);
  });

  test('activeLensSet overrides primary lens', () {
    final ctx = BibleOpticsContext.resolve(
      primaryLens: null,
      activeLensSet: {
        'isAnamorphic': false,
        'squeezeRatio': 1.0,
        'aspectRatio': '1.85:1',
      },
    );
    expect(ctx.isAnamorphic, isFalse);
    expect(ctx.aspectRatio, '1.85:1');
  });
}
