import 'package:flutter_test/flutter_test.dart';
import 'package:iris_dp/core/utils/scene_format.dart';

void main() {
  test('formatSceneMetaLine uses INT/EXT, day/night, location order', () {
    expect(
      formatSceneMetaLine(
        intExt: 'EXT',
        dayNight: 'NOCHE',
        location: 'PARADA DE BUS',
      ),
      'EXT · NOCHE · PARADA DE BUS',
    );
  });

  test('locationFromCanonical extracts location from slugline', () {
    expect(
      locationFromCanonical('INT. COCINA DE MARÍA - DÍA'),
      'COCINA DE MARÍA',
    );
  });
}
