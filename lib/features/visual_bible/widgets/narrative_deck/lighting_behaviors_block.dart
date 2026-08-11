import 'package:flutter/material.dart';

import 'lighting_behavior_mosaic.dart';

/// Comportamientos de la luz: mosaico de contenedores definidos por el usuario.
class LightingBehaviorsBlock extends StatelessWidget {
  final int projectId;
  final int bibleId;

  const LightingBehaviorsBlock({
    super.key,
    required this.projectId,
    required this.bibleId,
  });

  @override
  Widget build(BuildContext context) {
    return LightingBehaviorMosaicBlock(
      projectId: projectId,
      bibleId: bibleId,
    );
  }
}
