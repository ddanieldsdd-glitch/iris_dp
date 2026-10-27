import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';

import '../../core/database/app_database.dart';
import '../../core/utils/scene_color.dart';
import 'camera_plan_constants.dart';
import 'plan_element_external_mapping.dart';
import 'rig/plan_rig.dart';

/// Capa a la que pertenece un elemento de planta.
enum PlanLayer {
  /// Entorno de la localización.
  environment,

  /// Añadidos propios del set.
  set,

  /// Esquema de luz.
  light,

  /// Plano: cámaras y actores.
  shot,
}

extension PlanLayerLabel on PlanLayer {
  String get label => switch (this) {
    PlanLayer.environment => 'Entorno',
    PlanLayer.set => 'Set',
    PlanLayer.light => 'Luz',
    PlanLayer.shot => 'Cámara',
  };
}

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

  /// Propiedades por tipo (haz, intensidad, temperatura de color, focal…).
  Map<String, dynamic> props;

  /// Capa en la que se guarda. Solo en memoria: la da quien carga la planta.
  PlanLayer layer = PlanLayer.shot;

  /// Es un elemento del esquema de luz ajustado solo para el plano
  /// abierto. Solo en memoria.
  bool shotOverride = false;

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
    Map<String, dynamic>? props,
  }) : externalMapping = externalMapping ?? PlanElementExternalMapping(),
       actorColor = actorColor ?? kActorColors.first,
       pathPoints = pathPoints ?? [],
       props = props ?? {};

  String get cameraLabel => '$cameraLetter-$cameraNumber';

  PropType? get propType =>
      type == ElementType.prop ? PropTypeCodec.fromLabel(label) : null;

  ArchitectureType? get architectureType =>
      type == ElementType.wall ? ArchitectureTypeCodec.fromLabel(label) : null;

  static Map<String, dynamic> decodeProps(String? json) {
    if (json == null || json.isEmpty) return {};
    try {
      return Map<String, dynamic>.from(jsonDecode(json) as Map);
    } catch (_) {
      return {};
    }
  }

  /// Nombre libre del elemento (`props['name']`), para cualquier tipo salvo
  /// los actores, que usan [label]. Lo usan la planta, el 3D, Unreal y las
  /// listas.
  static const nameKey = 'name';

  String? get customName {
    final name = props[nameKey];
    return name is String && name.trim().isNotEmpty ? name.trim() : null;
  }

  set customName(String? value) {
    final name = value?.trim();
    if (name == null || name.isEmpty) {
      props.remove(nameKey);
    } else {
      props[nameKey] = name;
    }
  }

  /// Cómo se llama: su nombre libre o, si no tiene, su tipo.
  String get displayLabel => type == ElementType.actor
      ? label ?? 'Actor'
      : customName ?? typeLabel;

  /// Qué es: el tipo (o «A-1» en una cámara), sin el nombre libre.
  String get typeLabel => switch (type) {
    ElementType.camera => cameraLabel,
    ElementType.actor => label ?? 'Actor',
    ElementType.light => lightType?.label ?? 'Luz',
    ElementType.prop =>
      RigTypeCodec.of(this)?.label ?? propType?.label ?? 'Prop',
    ElementType.wall => switch (props['kind']) {
      'street' => 'Calle',
      'relief' => 'Relieve',
      'drape' => 'Tela',
      _ => architectureType?.label ?? 'Pared',
    },
  };

  static PlanElement fromDb(
    CameraPlanElement row, {
    List<CameraPathPoint> pathRows = const [],
  }) {
    final sorted = [...pathRows]
      ..sort((a, b) => a.pointNumber.compareTo(b.pointNumber));
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
      externalMapping: PlanElementExternalMapping.fromJson(
        row.externalMappingJson,
      ),
      actorColor: colorFromHex(row.color) ?? kActorColors.first,
      pathPoints: sorted.map((p) => Offset(p.x, p.y)).toList(),
      props: decodeProps(row.propsJson),
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
      propsJson: Value(props.isEmpty ? null : jsonEncode(props)),
      sortOrder: Value(sortOrder),
    );
  }
}
