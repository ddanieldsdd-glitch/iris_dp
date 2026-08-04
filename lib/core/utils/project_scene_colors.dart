import 'package:flutter/material.dart';

import '../database/app_database.dart';
import 'project_color_scheme.dart';
import 'scene_color.dart';

/// Fachada de colores para el workspace de importación del guion literario.
///
/// Delega en [ProjectColorScheme]; preferir [ProjectColorScheme.resolve]
/// en el resto de pantallas.
class ProjectSceneColors {
  final ProjectColorScheme _scheme;

  ProjectSceneColors({
    required List<LocationBasePlan> locations,
    List<LocationSite> sites = const [],
    List<Scene>? scenes,
    Map<String, String>? pendingSetColors,
  }) : _scheme = ProjectColorScheme.resolve(
          sites: sites,
          sets: locations,
          scenes: scenes,
          pendingSetColorsByName: pendingSetColors,
        );

  ProjectColorScheme get scheme => _scheme;

  Color siteColor(int? siteId, {String? orphanSiteKey}) =>
      _scheme.siteColor(siteId, orphanSiteKey: orphanSiteKey);

  Color setColor(LocationBasePlan set) => _scheme.setColor(set);

  Color sceneColor(Scene scene) => _scheme.sceneColor(scene);

  String? setColorHex(String shootSet, {String? locationSite}) =>
      hexFromColor(_scheme.forShootSet(
        shootSet,
        locationSiteName: locationSite,
      ));

  Color effective({
    required String shootSet,
    String? sceneColorOverride,
    String? locationSite,
  }) =>
      _scheme.forShootSet(
        shootSet,
        sceneColorOverride: sceneColorOverride,
        locationSiteName: locationSite,
      );

  Map<int, Color> colorsBySourceStartIndex({
    required Iterable<
            ({
              int? sourceStartIndex,
              String shootSet,
              String? sceneColorOverride,
              String? locationSite,
            })>
        scenes,
  }) =>
      _scheme.colorsBySourceStartIndex(scenes: scenes);
}
