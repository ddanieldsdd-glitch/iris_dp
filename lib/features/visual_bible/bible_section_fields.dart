export '../../shared/visual_bible/bible_section_fields.dart';

import 'visual_bible_model.dart';

/// Lectura/escritura de campos de dirección en VisualBibleData.
abstract final class DirectionFieldBinding {
  static String? read(VisualBibleData data, String key) => switch (key) {
        'tone' => data.tone,
        'creativeIntention' => data.creativeIntention,
        'stagingApproach' => data.stagingApproach,
        'pointOfView' => data.pointOfView,
        _ => null,
      };

  static void write(VisualBibleData data, String key, String? value) {
    switch (key) {
      case 'tone':
        data.tone = value;
      case 'creativeIntention':
        data.creativeIntention = value;
      case 'stagingApproach':
        data.stagingApproach = value;
      case 'pointOfView':
        data.pointOfView = value;
    }
  }
}
