import 'package:flutter/material.dart';

import '../database/app_database.dart';
import 'project_color_scheme.dart';
import 'scene_color.dart';

/// Resuelve colores efectivos de escenas (delegado en [ProjectColorScheme]).
class ProjectSceneColors {
  final ProjectColorScheme _scheme;

  ProjectSceneColors({
    required List<LocationBasePlan> locations,
    List<LocationSite> sites = const [],
    List<Scene>? scenes,
    Map<String, String>? pendingSetColors,
  }) : _scheme = ProjectColorScheme(
          sites: sites,
          sets: locations,
          scenes: scenes,
          pendingSetColorsByName: pendingSetColors,
        );

  ProjectColorScheme get scheme => _scheme;

  String? setColorForName(String shootSet) {
    final hex = _scheme.forShootSet(shootSet);
    return hexFromColor(hex);
  }

  Color effective({
    required String shootSet,
    String? sceneColorOverride,
  }) {
    return _scheme.forShootSet(
      shootSet,
      sceneColorOverride: sceneColorOverride,
    );
  }

  Map<int, Color> colorsBySourceStartIndex({
    required Iterable<
            ({int? sourceStartIndex, String shootSet, String? sceneColorOverride})>
        scenes,
  }) {
    return _scheme.colorsBySourceStartIndex(scenes: scenes);
  }
}
