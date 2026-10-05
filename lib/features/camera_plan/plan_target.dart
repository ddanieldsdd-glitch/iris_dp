import 'floor_plan_scope.dart';

/// Una planta concreta que se puede abrir: el entorno de una localización,
/// un set, un esquema de luz o un plano.
class PlanTarget {
  final FloorPlanScope scope;
  final int id;
  final String label;

  /// Tramo de un plano secuencia. `null` = el plano entero.
  final int? leg;

  const PlanTarget({
    required this.scope,
    required this.id,
    required this.label,
    this.leg,
  });

  const PlanTarget.site(this.id, this.label)
    : scope = FloorPlanScope.site,
      leg = null;
  const PlanTarget.set(this.id, this.label)
    : scope = FloorPlanScope.set,
      leg = null;
  const PlanTarget.lightSetup(this.id, this.label)
    : scope = FloorPlanScope.lightSetup,
      leg = null;
  const PlanTarget.shot(this.id, this.label, {this.leg})
    : scope = FloorPlanScope.shot;

  @override
  bool operator ==(Object other) =>
      other is PlanTarget &&
      other.scope == scope &&
      other.id == id &&
      other.leg == leg;

  @override
  int get hashCode => Object.hash(scope, id, leg);
}

/// Estado de un esquema de luz, como se enseña al usuario.
String lightSetupStatusLabel(String status) => switch (status) {
  'definitivo' => 'Definitivo',
  'en_desarrollo' => 'En desarrollo',
  _ => 'Boceto',
};
