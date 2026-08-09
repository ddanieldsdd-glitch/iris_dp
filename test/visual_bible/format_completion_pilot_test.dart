import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:iris_dp/features/visual_bible/visual_bible_completion.dart';
import 'package:iris_dp/features/visual_bible/visual_bible_model.dart';
import 'package:iris_dp/shared/visual_bible/bible_section_fields.dart';

void main() {
  test('completion Format usa blob canónico, no columnas stale', () {
    final formatContent = BibleSectionFieldsConfig.encode(
      BibleSectionFieldsConfig.defaultsFor(BibleSectionId.format),
      values: {
        'formatData': jsonEncode({
          'activeRatio': '2.39:1',
          'resolution': '4K',
          'intentNarrative': 'Intent blob',
        }),
      },
    );

    final data = VisualBibleData(
      id: 1,
      projectId: 1,
      aspectRatio: '1.85:1',
    );

    final withoutBlob = bibleSectionCompletion(data, BibleSectionId.format);
    final withBlob = bibleSectionCompletion(
      data,
      BibleSectionId.format,
      formatSectionContentJson: formatContent,
    );

    expect(withoutBlob, lessThan(1.0));
    expect(withBlob, 1.0);
  });
}
