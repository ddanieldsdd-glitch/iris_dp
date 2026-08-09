import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:iris_dp/features/visual_bible/visual_bible_completion.dart';
import 'package:iris_dp/features/visual_bible/visual_bible_model.dart';
import 'package:iris_dp/shared/visual_bible/bible_section_fields.dart';

void main() {
  test('completion Camera usa blob canónico, no columnas stale', () {
    final cameraContent = BibleSectionFieldsConfig.encode(
      BibleSectionFieldsConfig.defaultsFor(BibleSectionId.camera),
      values: {
        'cameraData': jsonEncode({
          'captureResolution': '4K',
        }),
      },
    );

    final data = VisualBibleData(
      id: 1,
      projectId: 1,
      primaryCameraId: 1,
      cameraPhilosophy: 'Observacional',
      movementStyle: 'Steadicam',
      recordingFormat: 'ProRes',
      cameraNarrativeIntent: 'Intención',
    );

    final withoutBlob = bibleSectionCompletion(data, BibleSectionId.camera);
    final withBlob = bibleSectionCompletion(
      data,
      BibleSectionId.camera,
      cameraSectionContentJson: cameraContent,
    );

    expect(withoutBlob, lessThan(1.0));
    expect(withBlob, 1.0);
  });
}
