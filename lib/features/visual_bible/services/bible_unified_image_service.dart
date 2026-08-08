import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../v2/model/bible_image_content.dart';
import '../v2/widgets/universal_bible_image_input.dart';
import '../widgets/bible_moodboard_image_target.dart';

/// Punto de entrada unificado para imágenes en Biblia (drop, paste, moodboard).
abstract final class BibleUnifiedImageService {
  /// Zona de drop reutilizable en secciones legacy Stitch.
  static Widget legacySectionTarget({
    required int projectId,
    required String sectionId,
    required Widget child,
    int? bibleId,
    String? hint,
  }) {
    return BibleMoodboardImageTarget(
      projectId: projectId,
      sectionId: sectionId,
      bibleId: bibleId,
      hint: hint,
      child: child,
    );
  }

  /// Input universal para bloques V2 / editor modular.
  static Widget blockInput({
    required int projectId,
    required ValueChanged<BibleImageContent> onChanged,
    BibleImageContent? value,
    VoidCallback? onClear,
  }) {
    return UniversalBibleImageInput(
      projectId: projectId,
      value: value,
      onChanged: onChanged,
      onClear: onClear,
    );
  }
}

/// Atajo Consumer para secciones legacy.
class BibleLegacyImageTarget extends ConsumerWidget {
  final int projectId;
  final String sectionId;
  final int? bibleId;
  final Widget child;

  const BibleLegacyImageTarget({
    super.key,
    required this.projectId,
    required this.sectionId,
    this.bibleId,
    required this.child,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return BibleUnifiedImageService.legacySectionTarget(
      projectId: projectId,
      sectionId: sectionId,
      bibleId: bibleId,
      child: child,
    );
  }
}
