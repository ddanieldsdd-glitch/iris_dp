import 'package:flutter/material.dart';

import 'lighting_behavior_mosaic.dart';

/// Comportamientos de la luz: mosaico de contenedores definidos por el usuario.
class LightingBehaviorsBlock extends StatelessWidget {
  final int projectId;
  final int bibleId;
  final bool compact;

  const LightingBehaviorsBlock({
    super.key,
    required this.projectId,
    required this.bibleId,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return LightingBehaviorMosaicBlock(
      projectId: projectId,
      bibleId: bibleId,
      compact: compact,
    );
  }
}
