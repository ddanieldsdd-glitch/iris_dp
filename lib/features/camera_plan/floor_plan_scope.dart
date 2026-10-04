/// Nivel de la jerarquía de planos 2D.
enum FloorPlanScope {
  /// Plano maestro de toda la localización (LocationSite.floorPlanJson).
  site,

  /// Plano base del set de rodaje (LocationBasePlan.floorPlanJson).
  set,

  /// Esquema de luz compartido entre planos (LightSetups.planJson).
  lightSetup,

  /// Planta de cámara de un plano concreto (CameraPlanElements).
  shot,
}

extension FloorPlanScopeLabel on FloorPlanScope {
  String get title => switch (this) {
    FloorPlanScope.site => 'Plano maestro',
    FloorPlanScope.set => 'Plano de set',
    FloorPlanScope.lightSetup => 'Esquema de luz',
    FloorPlanScope.shot => 'Planta de cámara',
  };

  String get subtitle => switch (this) {
    FloorPlanScope.site =>
      'Entorno de la localización: paredes, puertas, ventanas y props',
    FloorPlanScope.set => 'Arquitectura y props compartidos del set',
    FloorPlanScope.lightSetup => 'Luces y grip que comparten varios planos',
    FloorPlanScope.shot => 'Cámaras y actores de este plano',
  };
}
