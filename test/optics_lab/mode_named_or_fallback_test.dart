import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:iris_dp/core/database/app_database.dart';
import 'package:iris_dp/features/optics_lab/optics_calculator.dart';
import 'package:iris_dp/features/optics_lab/sensor_mode_utils.dart';
import 'package:iris_dp/shared/visual_bible/bible_section_fields.dart';
import 'package:iris_dp/shared/visual_bible/bible_section_ids.dart';
import 'package:iris_dp/shared/visual_bible/format_sensor_mode_resolve.dart';

void main() {
  test('modeNamedOrFallback respeta el nombre de Format', () {
    final cam = Camera(
      id: 1,
      brand: 'ARRI',
      model: 'ALEXA 35',
      sensorWidthMm: 28,
      sensorHeightMm: 19.2,
      sensorModesJson: jsonEncode([
        {
          'name': '4.6K 3:2 Open Gate',
          'widthMm': 28,
          'heightMm': 19.2,
          'maxWidthPx': 4608,
          'maxHeightPx': 3164,
        },
        {
          'name': '4K 16:9',
          'widthMm': 24.9,
          'heightMm': 14.0,
          'maxWidthPx': 4096,
          'maxHeightPx': 2304,
        },
      ]),
      isCustom: false,
      vintage: false,
      lukaCompatible: false,
    );

    final picked = modeNamedOrFallback(cam, '4K 16:9');
    expect(picked.name, '4K 16:9');
    expect(picked.maxWidthPx, 4096);

    final missing = modeNamedOrFallback(cam, 'modo-inexistente');
    expect(missing.name, '4.6K 3:2 Open Gate');
  });

  test('modeNameFromSectionContentJson lee formatData.sensorModeName', () {
    final content = BibleSectionFieldsConfig.encode(
      BibleSectionFieldsConfig.defaultsFor(BibleSectionId.format),
      values: {
        'formatData': jsonEncode({
          'sensorModeName': '4K 16:9',
          'sensorMode': '24.9:14.0',
        }),
      },
    );
    expect(
      FormatSensorModeResolve.modeNameFromSectionContentJson(content),
      '4K 16:9',
    );
  });
}
