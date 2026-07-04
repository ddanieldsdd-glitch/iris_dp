import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';

import '../../core/database/app_database.dart';
import '../../core/utils/scene_color.dart';
import 'camera_plan_constants.dart';
import 'plan_element_external_mapping.dart';

class PlanElement {
  int id;
  final ElementType type;
  Offset position;
  double rotation;
  String? label;
  String? stabilization;
  String? lens;
  int cameraNumber;
  String cameraLetter;
  LightType? lightType;
  bool lukaCompatible;
  String? lukaFixtureId;
  PlanElementExternalMapping externalMapping;
  Color actorColor;
  List<Offset> pathPoints;

  PlanElement({
    required this.id,
    required this.type,
    required this.position,
    this.rotation = 0,
    this.label,
    this.stabilization,
    this.lens,
    this.cameraNumber = 1,
    this.cameraLetter = 'A',
    this.lightType,
    this.lukaCompatible = false,
    this.lukaFixtureId,
    PlanElementExternalMapping? externalMapping,
    Color? actorColor,
    List<Offset>? pathPoints,
  })  : externalMapping = externalMapping ?? PlanElementExternalMapping(),
        actorColor = actorColor ?? kActorColors.first,
        pathPoints = pathPoints ?? [];

  String get cameraLabel => '$cameraLetter-$cameraNumber';

  PropType? get propType =>
      type == ElementType.prop ? PropTypeCodec.fromLabel(label) : null;

  ArchitectureType? get architectureType =>
      type == ElementType.wall ? ArchitectureTypeCodec.fromLabel(label) : null;

  String get displayLabel => switch (type) {
        ElementType.camera => cameraLabel,
        ElementType.actor => label ?? 'Actor',
        ElementType.light => lightType?.label ?? 'Luz',
        ElementType.prop => propType?.label ?? 'Prop',
        ElementType.wall => architectureType?.label ?? 'Pared',
      };

  static PlanElement fromDb(
    CameraPlanElement row, {
    List<CameraPathPoint> pathRows = const [],
  }) {
    final sorted = [...pathRows]..sort((a, b) => a.pointNumber.compareTo(b.pointNumber));
    return PlanElement(
      id: row.id,
      type: ElementTypeCodec.fromDb(row.type),
      position: Offset(row.x, row.y),
      rotation: row.rotation,
      label: row.label,
      stabilization: row.cameraStabilization,
      lens: row.cameraLens,
      cameraNumber: row.cameraNumber,
      cameraLetter: row.cameraLetter,
      lightType: LightTypeLabel.fromDb(row.lightType),
      lukaCompatible: row.lukaCompatible,
      lukaFixtureId: row.lukaFixtureId,
      externalMapping:
          PlanElementExternalMapping.fromJson(row.externalMappingJson),
      actorColor: colorFromHex(row.color) ?? kActorColors.first,
      pathPoints: sorted.map((p) => Offset(p.x, p.y)).toList(),
    );
  }

  CameraPlanElementsCompanion toCompanion(int shotId, {int sortOrder = 0}) {
    return CameraPlanElementsCompanion.insert(
      id: id > 0 ? Value(id) : const Value.absent(),
      shotId: shotId,
      type: type.dbValue,
      x: Value(position.dx),
      y: Value(position.dy),
      rotation: Value(rotation),
      label: Value(label),
      color: Value(type == ElementType.actor ? hexFromColor(actorColor) : null),
      cameraStabilization: Value(stabilization),
      cameraLens: Value(lens),
      cameraLetter: Value(cameraLetter),
      cameraNumber: Value(cameraNumber),
      lightType: Value(lightType?.dbValue),
      lukaCompatible: Value(lukaCompatible),
      lukaFixtureId: Value(lukaFixtureId),
      externalMappingJson: externalMapping.isEmpty
          ? const Value.absent()
          : Value(externalMapping.encode()),
      sortOrder: Value(sortOrder),
    );
  }
}
