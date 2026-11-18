import 'dart:math' as math;

import '../../core/database/app_database.dart';
import '../../core/database/rental_queries.dart';
import '../../features/camera_plan/camera_plan_constants.dart';
import '../../features/camera_plan/camera_plan_element_model.dart';
import '../../features/camera_plan/plan_data.dart';

/// Lo que dice la reserva de una línea de material.
enum MaterialStock {
  /// Sin reservas que mirar, o algo que no se puede buscar (un tipo de
  /// foco sin modelo, un soporte).
  unchecked,

  /// Reservado de sobra.
  reserved,

  /// Reservado, pero menos de lo que hace falta.
  short,

  /// No está en ninguna reserva de ese día.
  missing,
}

/// Una línea de la lista: cuántos hacen falta de algo y dónde se usa.
class MaterialLine {
  final String name;
  final int quantity;

  /// Dónde: «ENCENDIDO 3 · SALÓN 2» o «6/1, 6/3».
  final String detail;
  final MaterialStock stock;

  /// Lo que hay reservado, si se ha mirado.
  final int reserved;

  const MaterialLine({
    required this.name,
    this.quantity = 1,
    this.detail = '',
    this.stock = MaterialStock.unchecked,
    this.reserved = 0,
  });
}

/// Lo que un plano pide de material: sus focos, sus cámaras y los datos de
/// cámara de la ficha.
class MaterialShot {
  /// «6/1».
  final String tag;

  /// El set (esquema de luz) donde va, y su nombre.
  final int? setKey;
  final String setName;
  final List<PlanElement> lights;
  final List<PlanElement> cameras;
  final String? lens;
  final String? movement;
  final int? fps;
  final String? shutter;

  const MaterialShot({
    required this.tag,
    this.setKey,
    this.setName = '',
    this.lights = const [],
    this.cameras = const [],
    this.lens,
    this.movement,
    this.fps,
    this.shutter,
  });
}

/// Una línea de una reserva de alquiler: lo que se va a recoger.
typedef RentalStock = ({String name, int quantity});

/// El material que juega en una jornada: la luz de sus sets y lo que piden
/// sus planos de cámara, cruzado con las reservas de ese día.
class ShootDayMaterial {
  final List<MaterialLine> lights;
  final List<MaterialLine> bodies;
  final List<MaterialLine> lenses;
  final List<MaterialLine> supports;
  final List<MaterialLine> speeds;

  /// Si se ha cruzado con alguna reserva.
  final bool checked;

  const ShootDayMaterial({
    this.lights = const [],
    this.bodies = const [],
    this.lenses = const [],
    this.supports = const [],
    this.speeds = const [],
    this.checked = false,
  });

  bool get isEmpty =>
      lights.isEmpty &&
      bodies.isEmpty &&
      lenses.isEmpty &&
      supports.isEmpty &&
      speeds.isEmpty;

  /// Las líneas que no están reservadas, o no del todo.
  int get missingCount => [...lights, ...bodies, ...lenses]
      .where(
        (l) =>
            l.stock == MaterialStock.missing || l.stock == MaterialStock.short,
      )
      .length;

  /// Calcula la lista. De la luz cuenta lo máximo que se usa a la vez: el
  /// material va de set en set. Si hay [stock] (lo reservado para ese día),
  /// marca lo que falta.
  static ShootDayMaterial of(
    List<MaterialShot> shots, {
    List<RentalStock>? stock,
  }) {
    final check = stock != null;

    MaterialLine line(
      String name,
      int quantity,
      String detail, {
      bool find = true,
    }) {
      if (!check || !find) {
        return MaterialLine(name: name, quantity: quantity, detail: detail);
      }
      final have = reservedOf(name, stock);
      return MaterialLine(
        name: name,
        quantity: quantity,
        detail: detail,
        reserved: have,
        stock: have == 0
            ? MaterialStock.missing
            : have < quantity
            ? MaterialStock.short
            : MaterialStock.reserved,
      );
    }

    // Luz: por set, cada foco una vez (por su uid); luego, lo máximo.
    final setOrder = <int?>[];
    final setNames = <int?, String>{};
    final perSet = <int?, Map<String, Set<String>>>{};
    final hasModel = <String, bool>{};
    for (final shot in shots) {
      if (!setOrder.contains(shot.setKey)) setOrder.add(shot.setKey);
      setNames[shot.setKey] = shot.setName;
      final byName = perSet.putIfAbsent(shot.setKey, () => {});
      for (final light in shot.lights) {
        final name = light.model ?? light.typeLabel;
        hasModel[name] = light.model != null;
        final uid = light.props['uid']?.toString() ?? '${light.id}';
        byName.putIfAbsent(name, () => {}).add(uid);
      }
    }
    final lightNames = <String>[
      for (final key in setOrder) ...perSet[key]!.keys,
    ].toSet().toList();
    final lights = [
      for (final name in lightNames)
        () {
          final counts = [
            for (final key in setOrder)
              if (perSet[key]![name] case final uids?) (key, uids.length),
          ];
          final most = counts.fold(0, (n, c) => math.max(n, c.$2));
          final detail = setOrder.length < 2
              ? ''
              : [
                  for (final (key, n) in counts)
                    '${_or(setNames[key], 'Sin set')} $n',
                ].join(' · ');
          return line(name, most, detail, find: hasModel[name] ?? false);
        }(),
    ]..sort((a, b) => b.quantity.compareTo(a.quantity));

    // Cámaras: las que ruedan a la vez en un plano.
    var together = 0;
    final letters = <String>{};
    final models = <String, int>{};
    for (final shot in shots) {
      final inShot = {for (final c in shot.cameras) c.cameraLetter};
      together = math.max(together, inShot.length);
      letters.addAll(inShot);
      final byModel = <String, int>{};
      for (final c in shot.cameras) {
        if (c.model case final m?)
          byModel.update(m, (n) => n + 1, ifAbsent: () => 1);
      }
      for (final MapEntry(:key, :value) in byModel.entries) {
        models[key] = math.max(models[key] ?? 0, value);
      }
    }
    final bodies = [
      for (final MapEntry(:key, :value) in models.entries) line(key, value, ''),
      if (models.isEmpty && together > 0)
        line(
          together == 1 ? 'Cámara' : 'Cámaras',
          together,
          (letters.toList()..sort()).join(', '),
          find: false,
        ),
    ];

    // Ópticas y soportes: de la ficha de cada plano, con sus planos.
    List<(String, List<String>)> gather(String? Function(MaterialShot) field) {
      final display = <String, String>{};
      final where = <String, List<String>>{};
      for (final shot in shots) {
        for (final part in _parts(field(shot))) {
          final key = _compact(part);
          if (key.isEmpty) continue;
          display.putIfAbsent(key, () => part);
          final list = where.putIfAbsent(key, () => []);
          if (!list.contains(shot.tag)) list.add(shot.tag);
        }
      }
      return [for (final key in where.keys) (display[key]!, where[key]!)];
    }

    final lenses = [
      for (final (name, tags) in gather((s) => _lensName(s.lens)))
        line(name, 1, tags.join(', ')),
    ]..sort((a, b) => _focal(a.name).compareTo(_focal(b.name)));
    final supports = [
      for (final (name, tags) in gather((s) => s.movement))
        line(name.toUpperCase(), 1, tags.join(', '), find: false),
    ];

    // Velocidades fuera de lo normal.
    final special = <String, List<String>>{};
    for (final shot in shots) {
      if (shot.fps case final fps? when fps > 30) {
        special.putIfAbsent('$fps fps', () => []).add(shot.tag);
      }
      final shutter = shot.shutter?.trim();
      if (shutter != null &&
          shutter.isNotEmpty &&
          !shutter.startsWith('180') &&
          !shutter.startsWith('172')) {
        special
            .putIfAbsent('Obturación ${shutter.replaceAll('°', '')}°', () => [])
            .add(shot.tag);
      }
    }
    final speeds = [
      for (final MapEntry(:key, :value) in special.entries)
        line(key, 1, value.join(', '), find: false),
    ];

    return ShootDayMaterial(
      lights: lights,
      bodies: bodies,
      lenses: lenses,
      supports: supports,
      speeds: speeds,
      checked: check,
    );
  }

  /// Lo reservado de [name]: las líneas que llevan todas sus palabras.
  static int reservedOf(String name, List<RentalStock> stock) {
    final words = [
      for (final w in _words(name))
        if (w.length >= 2 || RegExp(r'\d').hasMatch(w)) w,
    ];
    if (words.isEmpty) return 0;
    var total = 0;
    for (final item in stock) {
      final hay = _compact(item.name);
      if (words.every(hay.contains)) total += item.quantity;
    }
    return total;
  }

  /// Carga el material de los [shots] de una jornada. Con [date] (ISO), se
  /// cruza con las reservas que lo cubren; sin reservas en el proyecto, no
  /// se marca nada.
  static Future<ShootDayMaterial> load(
    AppDatabase db,
    PlanProjectData data,
    int projectId,
    List<Shot> shots, {
    String? date,
  }) async {
    final items = <MaterialShot>[];
    for (final shot in shots) {
      final scene = data.scene(shot.sceneId);
      final setup = data.setup(shot.lightSetupId);
      items.add(
        MaterialShot(
          tag: '${scene?.label ?? ''}/${shot.number}',
          setKey: setup?.id,
          setName: setup?.name ?? '',
          lights: data.lightsOfShot(shot),
          cameras: [
            for (final el in data.ownOfShot(shot))
              if (el.type == ElementType.camera) el,
          ],
          lens: shot.lens,
          movement: shot.movement,
          fps: shot.fps,
          shutter: shot.shutterAngle,
        ),
      );
    }
    final reservations = await db.getRentalReservations(projectId);
    if (reservations.isEmpty) return of(items);
    final day = date == null || date.length < 10 ? null : date.substring(0, 10);
    bool covers(RentalReservation r) {
      if (day == null) return true;
      final from = r.pickupAt == null || r.pickupAt!.length < 10
          ? null
          : r.pickupAt!.substring(0, 10);
      final to = r.returnAt == null || r.returnAt!.length < 10
          ? null
          : r.returnAt!.substring(0, 10);
      return (from == null || from.compareTo(day) <= 0) &&
          (to == null || to.compareTo(day) >= 0);
    }

    final stock = <RentalStock>[];
    for (final r in reservations.where(covers)) {
      for (final item in await db.getRentalItemsIncludingDeleted(
        projectId,
        r.uid,
      )) {
        if (item.deletedAt != null || item.removedFromSourceAt != null) {
          continue;
        }
        stock.add((
          name: [item.groupLabel, item.name].nonNulls.join(' '),
          quantity: math.max(1, (item.quantity ?? 1).round()),
        ));
      }
    }
    return of(items, stock: stock);
  }

  static String _or(String? value, String fallback) =>
      value == null || value.trim().isEmpty ? fallback : value.trim();

  /// Las partes de un campo libre: «35mm / 50mm» son dos.
  static List<String> _parts(String? raw) => [
    for (final p in (raw ?? '').split(RegExp(r'[,/;+]|\s+y\s+|\s+o\s+')))
      if (p.trim().isNotEmpty) p.trim(),
  ];

  /// «35 mm» y «35MM» son la misma óptica.
  static String? _lensName(String? raw) => raw?.replaceAllMapped(
    RegExp(r'(\d)\s*mm\b', caseSensitive: false),
    (m) => '${m[1]}mm',
  );

  static double _focal(String name) =>
      double.tryParse(RegExp(r'\d+(\.\d+)?').firstMatch(name)?[0] ?? '') ??
      double.infinity;

  static const _accents = {
    'á': 'a',
    'é': 'e',
    'í': 'i',
    'ó': 'o',
    'ú': 'u',
    'ü': 'u',
    'ñ': 'n',
  };

  static String _plain(String s) =>
      s.toLowerCase().split('').map((c) => _accents[c] ?? c).join();

  static List<String> _words(String s) => [
    for (final w in _plain(s).split(RegExp(r'[^a-z0-9]+')))
      if (w.isNotEmpty) w,
  ];

  static String _compact(String s) => _words(s).join();
}
