import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_snackbar.dart';
import 'camera_plan_constants.dart';
import 'camera_plan_element_model.dart';
import 'light/plan_light.dart';
import 'light_beam.dart';

/// Número de unidad de cada aparato que emite, como en una hoja de luces:
/// U1, U2… en el orden en que están en la planta.
Map<PlanElement, int> lightUnitNumbers(Iterable<PlanElement> elements) {
  final numbers = <PlanElement, int>{};
  for (final el in elements) {
    if (el.type == ElementType.light && LightBeam.emits(el.lightType)) {
      numbers[el] = numbers.length + 1;
    }
  }
  return numbers;
}

/// «1800 W», «7,6 kW».
String formatWatts(double watts) => watts >= 1000
    ? '${(watts / 1000).toStringAsFixed(watts >= 10000 ? 0 : 1).replaceAll('.', ',')} kW'
    : '${watts.round()} W';

/// «850 lm», «26k lm».
String formatLumens(double lumens) => lumens >= 10000
    ? '${(lumens / 1000).round()}k lm'
    : lumens >= 1000
    ? '${(lumens / 1000).toStringAsFixed(1).replaceAll('.', ',')}k lm'
    : '${lumens.round()} lm';

/// Una fila de la leyenda de la planta: un modelo de aparato, cuántos hay,
/// qué potencia y luz da cada uno y qué unidades son.
class LightLegendRow {
  final String name;
  final int count;
  final double watts;
  final double lumens;
  final List<int> units;
  final LightType? symbol;

  const LightLegendRow({
    required this.name,
    required this.count,
    required this.watts,
    required this.lumens,
    required this.units,
    this.symbol,
  });

  /// «U1, U4» o «U1–U6».
  String get unitsLabel {
    if (units.isEmpty) return '';
    final sorted = [...units]..sort();
    final consecutive = sorted.last - sorted.first == sorted.length - 1;
    if (sorted.length > 2 && consecutive) {
      return 'U${sorted.first}–U${sorted.last}';
    }
    return sorted.map((u) => 'U$u').join(', ');
  }
}

/// La leyenda de equipo de una planta, como la de una hoja de WYSIWYG o
/// de Halfway: cada modelo con su potencia y su luz, y el total.
class LightLegend {
  final List<LightLegendRow> rows;

  /// Potencia de lo que está encendido.
  final double watts;

  const LightLegend(this.rows, this.watts);

  bool get isEmpty => rows.isEmpty;

  factory LightLegend.of(Iterable<PlanElement> elements) {
    final units = lightUnitNumbers(elements);
    final rows = <String, LightLegendRow>{};
    var total = 0.0;
    for (final MapEntry(key: el, value: unit) in units.entries) {
      final light = PlanLight.of(el);
      if (light == null) continue;
      if (LightBeam.of(el)?.off != true) total += light.watts;
      final name =
          (el.props['name'] as String?) ?? el.lightType?.label ?? 'Luz';
      final row = rows[name];
      rows[name] = LightLegendRow(
        name: name,
        count: (row?.count ?? 0) + 1,
        watts: light.watts,
        lumens: light.lumens,
        units: [...?row?.units, unit],
        symbol: el.lightType,
      );
    }
    return LightLegend(rows.values.toList(), total);
  }

  /// «Total 7,6 kW · 33 A a 230 V».
  String get totalLabel =>
      'Total ${formatWatts(watts)} · '
      '${(watts / GearList.mainsVolts).toStringAsFixed(1).replaceAll('.', ',')} A '
      'a ${GearList.mainsVolts.round()} V';
}

/// Una línea de la lista de material: cantidad y descripción.
class GearLine {
  final int count;
  final String label;

  /// Los elementos de la planta que suma esta línea.
  final List<PlanElement> elements;

  const GearLine(this.count, this.label, [this.elements = const []]);

  @override
  String toString() => '$count× $label';
}

/// Lista de material de una planta, agrupada como en una hoja de rodaje.
class GearList {
  final List<GearLine> lights;
  final List<GearLine> grip;
  final List<GearLine> cameras;

  /// Difusiones, redes y gelatinas puestas en los aparatos.
  final List<GearLine> filters;

  /// Truss, esquinas, motores, torres, garras y telas.
  final List<GearLine> rigging;

  /// Potencia de las luces encendidas, en vatios.
  final double watts;

  const GearList({
    this.filters = const [],
    this.watts = 0,
    this.lights = const [],
    this.grip = const [],
    this.cameras = const [],
    this.rigging = const [],
  });

  bool get isEmpty =>
      lights.isEmpty &&
      grip.isEmpty &&
      cameras.isEmpty &&
      filters.isEmpty &&
      rigging.isEmpty;

  /// Agrupa los elementos iguales y los cuenta. El rigging llega ya
  /// contado (necesita la escala de la planta).
  factory GearList.from(
    Iterable<PlanElement> elements, {
    List<GearLine> rigging = const [],
  }) {
    final lights = <String, int>{};
    final grip = <String, int>{};
    final cameras = <String, int>{};
    final filters = <String, int>{};
    var watts = 0.0;
    final members = <(Map<String, int>, String), List<PlanElement>>{};
    PlanElement? current;
    void add(Map<String, int> map, String key) {
      map.update(key, (n) => n + 1, ifAbsent: () => 1);
      if (current != null) {
        members.putIfAbsent((map, key), () => []).add(current);
      }
    }

    for (final el in elements) {
      current = el;
      switch (el.type) {
        case ElementType.light:
          final name =
              (el.props['name'] as String?) ?? el.lightType?.label ?? 'Luz';
          add(LightBeam.emits(el.lightType) ? lights : grip, name);
          final light = PlanLight.of(el);
          if (light != null && LightBeam.of(el)?.off != true) {
            watts += light.watts;
          }
          for (final m in PlanLight.of(el)?.modifiers ?? const []) {
            add(
              filters,
              m.reference == null ? m.name : '${m.name} (${m.reference})',
            );
          }
        case ElementType.camera:
          add(
            cameras,
            [
              'Cámara ${el.cameraLetter}',
              if (el.props['cameraName'] case final String body) body,
              if (el.props['lensName'] case final String glass) glass,
              if (el.lens?.isNotEmpty == true) el.lens!,
              if (el.stabilization?.isNotEmpty == true) el.stabilization!,
            ].join(' · '),
          );
        case ElementType.actor || ElementType.prop || ElementType.wall:
          break;
      }
    }

    List<GearLine> lines(Map<String, int> map) => [
      for (final e in map.entries)
        GearLine(e.value, e.key, members[(map, e.key)] ?? const []),
    ];
    return GearList(
      lights: lines(lights),
      grip: lines(grip),
      cameras: lines(cameras),
      filters: lines(filters),
      rigging: rigging,
      watts: watts,
    );
  }

  /// Tensión y calibre de un circuito doméstico en España y casi toda
  /// Europa.
  static const double mainsVolts = 230;
  static const double circuitAmps = 16;

  double get amps => watts / mainsVolts;

  /// Circuitos de 16 A que hacen falta, dejando un 20 % de margen en cada
  /// uno.
  int get circuits => watts <= 0 ? 0 : (amps / (circuitAmps * 0.8)).ceil();

  List<String> powerLines() => [
    '${watts.round()} W encendidos · ${amps.toStringAsFixed(1)} A a 230 V',
    '$circuits circuito${circuits == 1 ? '' : 's'} de 16 A '
        '(máx. ${(mainsVolts * circuitAmps * 0.8).round()} W cada uno)',
  ];

  /// Texto para pegar en un correo o en la orden de material.
  String toText({String? title}) {
    final buffer = StringBuffer();
    if (title != null) buffer.writeln(title);
    void section(String name, List<GearLine> lines) {
      if (lines.isEmpty) return;
      buffer.writeln(name);
      for (final line in lines) {
        buffer.writeln('  $line');
      }
    }

    section('LUCES', lights);
    section('GRIP', grip);
    section('DIFUSIÓN Y GELATINAS', filters);
    section('CÁMARA', cameras);
    section('RIGGING', rigging);
    if (watts > 0) {
      buffer.writeln('CORRIENTE');
      for (final line in powerLines()) {
        buffer.writeln('  $line');
      }
    }
    return buffer.toString().trimRight();
  }
}

/// Panel con la lista de material del esquema de luz y del plano abiertos.
class PlanGearListPanel extends StatelessWidget {
  final GearList gear;
  final String title;

  /// Tocar una línea señala en la planta lo que suma.
  final ValueChanged<GearLine>? onPick;

  const PlanGearListPanel({
    super.key,
    required this.gear,
    required this.title,
    this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    Widget section(String name, List<GearLine> lines) {
      if (lines.isEmpty) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              name,
              style: AppTypography.caption(palette).copyWith(
                color: palette.accent,
                letterSpacing: 1.4,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            for (final line in lines)
              InkWell(
                onTap: onPick == null || line.elements.isEmpty
                    ? null
                    : () => onPick!(line),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Text(
                    line.toString(),
                    style: AppTypography.bodyMedium(palette),
                  ),
                ),
              ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Lista de material', style: AppTypography.label(palette)),
          Text(title, style: AppTypography.caption(palette)),
          const SizedBox(height: AppSpacing.md),
          Expanded(
            child: gear.isEmpty
                ? Text(
                    'Añade luces, grip o cámaras desde la paleta y aparecerán '
                    'aquí, contadas.',
                    style: AppTypography.bodyMedium(
                      palette,
                    ).copyWith(color: palette.textTertiary),
                  )
                : ListView(
                    children: [
                      section('LUCES', gear.lights),
                      section('GRIP', gear.grip),
                      section('DIFUSIÓN Y GELATINAS', gear.filters),
                      section('CÁMARA', gear.cameras),
                      section('RIGGING', gear.rigging),
                      if (gear.watts > 0)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'CORRIENTE',
                              style: AppTypography.caption(palette).copyWith(
                                color: palette.accent,
                                letterSpacing: 1.4,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            for (final line in gear.powerLines())
                              Text(
                                line,
                                style: AppTypography.bodyMedium(palette),
                              ),
                          ],
                        ),
                    ],
                  ),
          ),
          if (!gear.isEmpty)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.copy, size: 16),
                label: const Text('Copiar lista'),
                onPressed: () async {
                  await Clipboard.setData(
                    ClipboardData(text: gear.toText(title: title)),
                  );
                  if (context.mounted) {
                    AppSnackBar.show(context, 'Lista de material copiada.');
                  }
                },
              ),
            ),
        ],
      ),
    );
  }
}
