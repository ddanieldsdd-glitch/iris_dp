import 'camera_plan_constants.dart';
import 'camera_plan_element_model.dart';
import 'light/plan_light.dart';
import 'light_beam.dart';
import 'plan_gear_list.dart';

/// Un aparato encendido, visto por el eléctrico.
class PowerLoad {
  final PlanElement element;
  final int unit;
  final String name;
  final double watts;

  const PowerLoad(this.element, this.unit, this.name, this.watts);

  @override
  String toString() => 'U$unit $name · ${formatWatts(watts)}';
}

class PowerCircuit {
  final int number;
  final List<PowerLoad> loads;

  const PowerCircuit(this.number, this.loads);

  double get watts => loads.fold(0, (sum, l) => sum + l.watts);
}

/// Reparto de los aparatos en circuitos: cuánto carga cada uno y qué hace
/// falta para alimentarlo todo. Las cifras son orientativas: las comprueba
/// el eléctrico del rodaje.
class PowerPlan {
  /// Número de circuito en la planta (`props`).
  static const circuitKey = 'circuit';

  /// Un circuito se carga como mucho al 80 %, como en el resto de la app.
  static const margin = 0.8;

  /// Grupos electrógenos habituales, en kVA.
  static const generatorSizes = <double>[
    2.2,
    3.5,
    5,
    6.5,
    10,
    15,
    20,
    30,
    45,
    60,
    100,
    150,
  ];

  final double volts;
  final double breakerAmps;
  final List<PowerCircuit> circuits;
  final List<PowerLoad> unassigned;

  const PowerPlan({
    required this.volts,
    required this.breakerAmps,
    required this.circuits,
    required this.unassigned,
  });

  factory PowerPlan.of(
    Iterable<PlanElement> elements, {
    double volts = GearList.mainsVolts,
    double breakerAmps = GearList.circuitAmps,
  }) {
    final byCircuit = <int, List<PowerLoad>>{};
    final free = <PowerLoad>[];
    for (final load in loadsOf(elements)) {
      final circuit = (load.element.props[circuitKey] as num?)?.toInt();
      if (circuit == null || circuit < 1) {
        free.add(load);
      } else {
        byCircuit.putIfAbsent(circuit, () => []).add(load);
      }
    }
    final numbers = byCircuit.keys.toList()..sort();
    return PowerPlan(
      volts: volts,
      breakerAmps: breakerAmps,
      circuits: [for (final n in numbers) PowerCircuit(n, byCircuit[n]!)],
      unassigned: free,
    );
  }

  /// Lo que consume electricidad y está encendido.
  static List<PowerLoad> loadsOf(Iterable<PlanElement> elements) {
    final units = lightUnitNumbers(elements);
    return [
      for (final MapEntry(key: el, value: unit) in units.entries)
        if (LightBeam.of(el)?.off != true)
          if (PlanLight.of(el) case final light? when light.watts > 0)
            PowerLoad(
              el,
              unit,
              (el.props['name'] as String?) ?? el.lightType?.label ?? 'Luz',
              light.watts,
            ),
    ];
  }

  double get limitWatts => volts * breakerAmps * margin;

  double get totalWatts =>
      unassigned.fold<double>(0, (s, l) => s + l.watts) +
      circuits.fold<double>(0, (s, c) => s + c.watts);

  double ampsOf(double watts) => watts / volts;

  bool isOver(PowerCircuit c) => c.watts > limitWatts;

  /// Aparatos que no caben en un circuito de este calibre ni solos.
  List<PowerLoad> get tooBig => [
    for (final l in [...unassigned, ...circuits.expand((c) => c.loads)])
      if (l.watts > limitWatts) l,
  ];

  /// Reparto automático: de mayor a menor, cada aparato en el primer
  /// circuito donde quepa. Devuelve el circuito de cada elemento. Uno que no
  /// cabe en ninguno va solo, y [tooBig] lo señala.
  static Map<PlanElement, int> distribute(
    List<PowerLoad> loads,
    double limitWatts,
  ) {
    final sorted = [...loads]..sort((a, b) => b.watts.compareTo(a.watts));
    final used = <double>[];
    final out = <PlanElement, int>{};
    for (final load in sorted) {
      var slot = used.indexWhere((w) => w + load.watts <= limitWatts);
      if (slot < 0) {
        used.add(0);
        slot = used.length - 1;
      }
      used[slot] += load.watts;
      out[load.element] = slot + 1;
    }
    return out;
  }

  /// Carga por fase en una acometida trifásica: cada circuito a la fase que
  /// va más libre.
  List<double> get phases {
    final phase = [0.0, 0.0, 0.0];
    final sorted = [...circuits]..sort((a, b) => b.watts.compareTo(a.watts));
    for (final c in sorted) {
      var low = 0;
      for (var i = 1; i < 3; i++) {
        if (phase[i] < phase[low]) low = i;
      }
      phase[low] += c.watts;
    }
    return phase;
  }

  /// Grupo electrógeno recomendado, en kVA: la carga con factor de potencia
  /// 0,8 y al 80 % del grupo. `null` si no hay carga o supera el mayor.
  double? get generatorKva {
    if (totalWatts <= 0) return null;
    final needed = totalWatts / 1000 / 0.8 / margin;
    for (final size in generatorSizes) {
      if (size >= needed) return size;
    }
    return null;
  }

  /// Texto para pasar al eléctrico.
  String toText({String? title}) {
    final buffer = StringBuffer();
    if (title != null) buffer.writeln(title);
    buffer.writeln(
      'Total ${formatWatts(totalWatts)} · '
      '${ampsOf(totalWatts).toStringAsFixed(1)} A a ${volts.round()} V',
    );
    for (final c in circuits) {
      buffer.writeln(
        'Circuito ${c.number} · ${formatWatts(c.watts)} · '
        '${ampsOf(c.watts).toStringAsFixed(1)} A de '
        '${breakerAmps.round()} A${isOver(c) ? ' · SOBRECARGADO' : ''}',
      );
      for (final l in c.loads) {
        buffer.writeln('  $l');
      }
    }
    if (unassigned.isNotEmpty) {
      buffer.writeln('Sin circuito');
      for (final l in unassigned) {
        buffer.writeln('  $l');
      }
    }
    if (generatorKva case final kva?) {
      final label = kva == kva.roundToDouble()
          ? kva.toStringAsFixed(0)
          : kva.toString();
      buffer.writeln('Grupo orientativo: $label kVA');
    }
    return buffer.toString().trimRight();
  }
}
