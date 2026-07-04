/// Nivel de la jerarquía de planos 2D.
enum FloorPlanScope {
  /// Plano maestro de toda la localización (LocationSite.floorPlanJson).
  site,

  /// Plano base del set de rodaje (LocationBasePlan.floorPlanJson).
  set,

  /// Planta de cámara de un plano concreto (CameraPlanElements).
  shot,
}

extension FloorPlanScopeLabel on FloorPlanScope {
  String get title => switch (this) {
        FloorPlanScope.site => 'Plano maestro',
        FloorPlanScope.set => 'Plano de set',
        FloorPlanScope.shot => 'Planta de cámara',
      };

  String get subtitle => switch (this) {
        FloorPlanScope.site =>
          'Vista general con todos los sets de la localización',
        FloorPlanScope.set => 'Arquitectura y props compartidos del set',
        FloorPlanScope.shot => 'Cámaras, actores y luces de este plano',
      };
}
