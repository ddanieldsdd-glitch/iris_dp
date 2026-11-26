import 'dart:math' as math;
import 'dart:ui';

import '../camera_plan_constants.dart';
import '../camera_plan_element_model.dart';
import '../light/light_scene.dart';
import '../light_overrides.dart';
import '../plan_opening.dart';
import '../plan_seats.dart';
import '../light/street_lamp.dart';
import '../plan_segment.dart';
import '../plan_street.dart';
import '../rig/plan_hall.dart';
import '../rig/plan_rig.dart';
import 'arch_material.dart';
import 'arch_roof.dart';
import 'arch_solid.dart';
import 'arch_stair.dart';
import 'arch_sweep.dart';
import 'arch_terrain.dart';
import 'plan_levels.dart';

/// Los grupos de lugares de AM.8.
enum RecipeGroup {
  home('Casa e interiores'),
  city('Edificio y calle'),
  rail('Estación y vagón'),
  nature('Naturaleza');

  const RecipeGroup(this.label);
  final String label;
}

/// Un lugar tipo que se construye solo con las piezas del motor (AM.8).
enum RecipeKind {
  house(
    'Casa',
    RecipeGroup.home,
    'Por plantas: habitaciones, puertas, ventanas, forjados, escalera y '
        'tejado',
  ),
  room(
    'Habitación',
    RecipeGroup.home,
    'Dormitorio, cocina, baño, salón o bar, con sus muebles',
  ),
  building(
    'Edificio',
    RecipeGroup.city,
    'Plantas con fachada por módulos, balcones y bajo comercial',
  ),
  street(
    'Calle con edificios',
    RecipeGroup.city,
    'Calzada, aceras y farolas, con edificios a uno o a los dos lados',
  ),
  bridge(
    'Puente',
    RecipeGroup.city,
    'Tablero sobre pilas o arco de piedra, y el río debajo',
  ),
  station(
    'Estación',
    RecipeGroup.rail,
    'Andén a su altura, vías, catenaria, marquesina y escalera',
  ),
  carriage(
    'Vagón',
    RecipeGroup.rail,
    'Por dentro: suelo, ventanas, puertas, bancos y mesas para sentar a '
        'los personajes',
  ),
  mountain(
    'Montaña',
    RecipeGroup.nature,
    'Terreno con cumbres; hierba, tierra y roca por altura',
  ),
  beach('Playa', RecipeGroup.nature, 'Paseo con barandilla, arena y mar');

  const RecipeKind(this.label, this.group, this.hint);
  final String label;
  final RecipeGroup group;
  final String hint;
}

/// Un mando del panel de una receta: un número con su rango, una
/// elección entre opciones o un sí/no.
class RecipeKnob {
  final String key;
  final String label;
  final Object initial;
  final double min, max, step;
  final List<(String, String)> options;

  const RecipeKnob.number(
    this.key,
    this.label,
    double this.initial, {
    required this.min,
    required this.max,
    this.step = 0.1,
  }) : options = const [];

  const RecipeKnob.choice(
    this.key,
    this.label,
    String this.initial,
    this.options,
  ) : min = 0,
      max = 0,
      step = 0;

  const RecipeKnob.toggle(this.key, this.label, bool this.initial)
    : min = 0,
      max = 0,
      step = 0,
      options = const [];

  bool get isNumber => initial is double;
  bool get isChoice => options.isNotEmpty;
  bool get isToggle => initial is bool;
}

/// Recetas de lugar (AM.8), como la nave: un elemento receta guarda el
/// tipo y sus medidas, y genera piezas normales del motor marcadas con su
/// `uid`. Cambiar la receta las rehace; lo tocado a mano se despega y se
/// respeta.
abstract final class ArchRecipe {
  static const kindKey = 'recipeKind';
  static const paramsKey = 'recipeParams';

  /// En cada pieza que genera: el `uid` de la receta.
  static const ownerKey = 'recipeUid';

  /// Lo tocado a mano: la receta ya no lo rehace.
  static const detachedKey = PlanHall.detachedKey;

  static bool isRecipe(PlanElement el) => RigTypeCodec.of(el) == RigType.recipe;

  static RecipeKind kind(PlanElement el) =>
      RecipeKind.values.asNameMap()[el.props[kindKey]] ?? RecipeKind.house;

  static String? ownerOf(PlanElement el) => el.props[ownerKey] as String?;

  /// Lo que se puede cambiar de cada receta, con medidas de la vida real.
  static List<RecipeKnob> knobs(RecipeKind k) => switch (k) {
    RecipeKind.house => const [
      RecipeKnob.number('widthM', 'Ancho', 10, min: 6, max: 24, step: 0.5),
      RecipeKnob.number('depthM', 'Fondo', 8, min: 6, max: 20, step: 0.5),
      RecipeKnob.number('floors', 'Plantas', 2, min: 1, max: 3, step: 1),
      RecipeKnob.number(
        'rooms',
        'Habitaciones al fondo',
        2,
        min: 1,
        max: 4,
        step: 1,
      ),
      RecipeKnob.number(
        'storeyM',
        'Altura de planta',
        2.8,
        min: 2.5,
        max: 3.6,
        step: 0.05,
      ),
      RecipeKnob.choice('roof', 'Tejado', 'gable', [
        ('gable', 'Dos aguas'),
        ('hip', 'Cuatro aguas'),
        ('flat', 'Plano'),
      ]),
      RecipeKnob.choice('wallMat', 'Fachada', 'paint-cream', [
        ('paint-cream', 'Pintura crema'),
        ('paint-white', 'Pintura blanca'),
        ('brick-old', 'Ladrillo viejo'),
        ('stone-paving', 'Piedra'),
      ]),
    ],
    RecipeKind.room => const [
      RecipeKnob.choice('type', 'Qué es', 'living', [
        ('bedroom', 'Dormitorio'),
        ('kitchen', 'Cocina'),
        ('bathroom', 'Baño'),
        ('living', 'Salón'),
        ('bar', 'Bar'),
      ]),
      RecipeKnob.number('widthM', 'Ancho', 4.5, min: 2, max: 14, step: 0.1),
      RecipeKnob.number('depthM', 'Fondo', 4, min: 2, max: 12, step: 0.1),
      RecipeKnob.number('heightM', 'Alto', 2.6, min: 2.2, max: 4.5, step: 0.05),
    ],
    RecipeKind.building => const [
      RecipeKnob.number('widthM', 'Frente', 16, min: 6, max: 60, step: 1),
      RecipeKnob.number('depthM', 'Fondo', 12, min: 6, max: 40, step: 1),
      RecipeKnob.number('floors', 'Plantas', 5, min: 1, max: 12, step: 1),
      RecipeKnob.number(
        'storeyM',
        'Altura de planta',
        3,
        min: 2.6,
        max: 4,
        step: 0.05,
      ),
      RecipeKnob.number(
        'moduleM',
        'Módulo de fachada',
        3,
        min: 2,
        max: 6,
        step: 0.25,
      ),
      RecipeKnob.toggle('shop', 'Bajo comercial', true),
      RecipeKnob.toggle('balconies', 'Balcones', true),
      RecipeKnob.choice('wallMat', 'Fachada', 'brick-tan', [
        ('brick-tan', 'Ladrillo'),
        ('brick-old', 'Ladrillo viejo'),
        ('paint-cream', 'Revoco crema'),
        ('concrete-smooth', 'Hormigón'),
      ]),
    ],
    RecipeKind.street => const [
      RecipeKnob.number('lengthM', 'Largo', 60, min: 20, max: 200, step: 1),
      RecipeKnob.number('roadM', 'Calzada', 7, min: 3, max: 20, step: 0.5),
      RecipeKnob.number('walkM', 'Aceras', 3, min: 1, max: 8, step: 0.5),
      RecipeKnob.number(
        'frontM',
        'Frente de cada edificio',
        16,
        min: 8,
        max: 40,
        step: 1,
      ),
      RecipeKnob.number('floors', 'Plantas', 4, min: 1, max: 12, step: 1),
      RecipeKnob.toggle('both', 'Edificios a los dos lados', true),
    ],
    RecipeKind.bridge => const [
      RecipeKnob.number('lengthM', 'Largo', 40, min: 10, max: 200, step: 1),
      RecipeKnob.number('widthM', 'Ancho', 8, min: 3, max: 30, step: 0.5),
      RecipeKnob.number(
        'heightM',
        'Altura del tablero',
        5,
        min: 1,
        max: 40,
        step: 0.5,
      ),
      RecipeKnob.choice('type', 'Estructura', 'piers', [
        ('piers', 'Tablero sobre pilas'),
        ('arch', 'Arco'),
      ]),
      RecipeKnob.number('spanM', 'Entre pilas', 20, min: 6, max: 60, step: 1),
      RecipeKnob.toggle('river', 'Río debajo', true),
    ],
    RecipeKind.station => const [
      RecipeKnob.number('lengthM', 'Largo del andén', 60, min: 20, max: 300),
      RecipeKnob.number(
        'platformM',
        'Altura del andén',
        0.9,
        min: 0.55,
        max: 1.1,
        step: 0.01,
      ),
      RecipeKnob.number(
        'widthM',
        'Ancho del andén',
        6,
        min: 3,
        max: 15,
        step: 0.5,
      ),
      RecipeKnob.number('tracks', 'Vías', 2, min: 1, max: 2, step: 1),
      RecipeKnob.toggle('canopy', 'Marquesina', true),
      RecipeKnob.toggle('catenary', 'Catenaria', true),
      RecipeKnob.toggle('underpass', 'Paso subterráneo', true),
    ],
    RecipeKind.carriage => const [
      RecipeKnob.choice('layout', 'Asientos', 'tables', [
        ('tables', 'Enfrentados con mesa'),
        ('rows', 'En filas'),
        ('metro', 'Bancos a los lados'),
      ]),
      RecipeKnob.number('lengthM', 'Largo', 20, min: 8, max: 27, step: 0.5),
      RecipeKnob.number('widthM', 'Ancho', 2.9, min: 2.4, max: 3.4, step: 0.05),
      RecipeKnob.number(
        'floorM',
        'Altura del piso',
        1.1,
        min: 0.3,
        max: 1.3,
        step: 0.05,
      ),
      RecipeKnob.number(
        'pitchM',
        'Entre filas',
        1.8,
        min: 0.8,
        max: 2.4,
        step: 0.05,
      ),
      RecipeKnob.toggle('doors', 'Puertas a los lados', true),
    ],
    RecipeKind.mountain => const [
      RecipeKnob.number('sizeM', 'Tamaño', 120, min: 40, max: 400, step: 5),
      RecipeKnob.number('peakM', 'Cumbre', 30, min: 5, max: 200, step: 1),
      RecipeKnob.number('seed', 'Forma', 1, min: 1, max: 30, step: 1),
    ],
    RecipeKind.beach => const [
      RecipeKnob.number('widthM', 'Largo', 60, min: 20, max: 200, step: 1),
      RecipeKnob.number('depthM', 'Fondo', 40, min: 20, max: 120, step: 1),
      RecipeKnob.number('promenadeM', 'Paseo', 6, min: 3, max: 15, step: 0.5),
      RecipeKnob.number(
        'wallM',
        'Muro del paseo',
        1.8,
        min: 0.5,
        max: 4,
        step: 0.1,
      ),
    ],
  };

  /// Una receta nueva con su centro en [origin] (lienzo).
  static PlanElement create(
    RecipeKind k,
    Offset origin, {
    Map<String, Object>? params,
  }) {
    final el = RigTypeCodec.create(
      RigType.recipe,
      origin,
      props: {
        kindKey: k.name,
        paramsKey: {
          for (final knob in knobs(k)) knob.key: knob.initial,
          ...?params,
        },
      },
    );
    LightOverrides.ensureUids([el]);
    return el;
  }

  /// El valor de un mando, o el de siempre.
  static Object value(PlanElement el, String key) {
    final raw = el.props[paramsKey];
    final knob = knobs(kind(el)).firstWhere((k) => k.key == key);
    final v = raw is Map ? raw[key] : null;
    if (knob.isNumber) {
      return ((v as num?)?.toDouble() ?? knob.initial as double).clamp(
        knob.min,
        knob.max,
      );
    }
    if (knob.isToggle) return v is bool ? v : knob.initial;
    return v is String && knob.options.any((o) => o.$1 == v) ? v : knob.initial;
  }

  static double number(PlanElement el, String key) => value(el, key) as double;

  static void set(PlanElement el, String key, Object v) {
    final raw = el.props[paramsKey];
    el.props[paramsKey] = {
      if (raw is Map) ...raw.cast<String, Object>(),
      key: v,
    };
  }

  /// Lo que se ve en el panel.
  static String summary(PlanElement el, List<PlanElement> pieces) {
    final k = kind(el);
    final mine = pieces.where((p) => ownerOf(p) == LightOverrides.uidOf(el));
    final touched = mine.where((p) => p.props[detachedKey] == true).length;
    return '${k.label} · ${mine.length} piezas'
        '${touched == 0 ? '' : ' · $touched tocadas a mano, que se respetan'}'
        '.';
  }

  /// Una pieza generada tocada a mano: se despega de la receta.
  static bool markTouched(PlanElement el) {
    if (ownerOf(el) == null || isRecipe(el)) return false;
    if (el.props[detachedKey] == true) return false;
    el.props[detachedKey] = true;
    return true;
  }

  /// Rehace lo generado por [recipe]: quita lo de antes (salvo lo
  /// despegado) y añade lo nuevo.
  static void regenerate(
    List<PlanElement> elements,
    PlanElement recipe,
    double mpu,
  ) {
    final uid = LightOverrides.uidOf(recipe);
    if (uid == null) return;
    final kept = <String>{
      for (final el in elements)
        if (ownerOf(el) == uid && el.props[detachedKey] == true)
          ?LightOverrides.uidOf(el),
    };
    elements.removeWhere(
      (el) => ownerOf(el) == uid && el.props[detachedKey] != true,
    );
    elements.addAll(
      build(
        recipe,
        mpu,
      ).where((el) => !kept.contains(LightOverrides.uidOf(el))),
    );
  }

  /// Las piezas de la receta, sin la receta.
  static List<PlanElement> build(PlanElement recipe, double mpu) {
    final uid = LightOverrides.uidOf(recipe);
    if (uid == null) return const [];
    final b = _Builder(recipe, uid, mpu);
    switch (kind(recipe)) {
      case RecipeKind.house:
        _house(b);
      case RecipeKind.room:
        _room(b);
      case RecipeKind.building:
        _building(b);
      case RecipeKind.street:
        _street(b);
      case RecipeKind.bridge:
        _bridge(b);
      case RecipeKind.station:
        _station(b);
      case RecipeKind.carriage:
        _carriage(b);
      case RecipeKind.mountain:
        _mountain(b);
      case RecipeKind.beach:
        _beach(b);
    }
    for (final el in b.out) {
      el.layer = recipe.layer;
    }
    return b.out;
  }

  /// Una receta suelta con sus piezas, para empezar un set con ella
  /// («Nuevo set»): todo en el entorno, centrado en el origen.
  static List<PlanElement> standalone(
    RecipeKind k, {
    double mpu = defaultMetersPerUnit,
  }) {
    final recipe = create(k, Offset.zero)..layer = PlanLayer.environment;
    return [recipe, ...build(recipe, mpu)];
  }

  // ── Casa e interiores ────────────────────────────────────────────────

  static const _door = (w: 0.82, h: 2.03);

  static void _house(_Builder b) {
    final w = b.n('widthM'), d = b.n('depthM');
    final floors = b.n('floors').round();
    final storey = b.n('storeyM');
    final mat = b.s('wallMat');
    final hw = w / 2, hd = d / 2;
    // La escalera, junto a la pared derecha, de delante hacia el fondo.
    final risers = (storey / 0.175).round();
    final run = math.min(d - 1.2, (risers - 1) * 0.28);
    const stairW = 1.0;
    final stairX = hw - 0.15 - stairW / 2;
    for (var f = 0; f < floors; f++) {
      final z = f * storey;
      final t = 'p$f';
      // Fachada.
      for (final (i, (a, c)) in [
        (Offset(-hw, -hd), Offset(hw, -hd)),
        (Offset(hw, -hd), Offset(hw, hd)),
        (Offset(hw, hd), Offset(-hw, hd)),
        (Offset(-hw, hd), Offset(-hw, -hd)),
      ].indexed) {
        b.wall('$t-w$i', a, c, level: z, height: storey, thick: 0.25, mat: mat);
      }
      // Tabiques: uno de lado a lado (sin cortar la escalera) y otros que
      // parten el fondo en las habitaciones que se pidan, cada una con su
      // puerta.
      final edge = hw - 0.15 - stairW - 0.1;
      b.wall(
        '$t-t0',
        Offset(-hw, 0),
        Offset(edge, 0),
        level: z,
        height: storey,
        thick: 0.1,
        mat: 'paint-white',
      );
      final rooms = b.n('rooms').round();
      final roomW = (edge + hw) / rooms;
      for (var k = 0; k < rooms; k++) {
        final x0 = -hw + k * roomW;
        if (k > 0) {
          b.wall(
            '$t-t$k',
            Offset(x0, -hd),
            Offset(x0, 0),
            level: z,
            height: storey,
            thick: 0.1,
            mat: 'paint-white',
          );
        }
        if (roomW >= _door.w + 0.3) {
          b.opening(
            '$t-d$k',
            ArchitectureType.doorClosed,
            Offset(x0 + roomW / 2, 0),
            0,
            _door.w,
            head: _door.h,
            level: z,
          );
        }
      }
      // Ventanas: dos al fondo, una por lado y, delante, una arriba y
      // dos abajo con la puerta.
      for (final x in [-hw / 2, hw / 2]) {
        b.window('$t-wb$x', Offset(x, -hd), 0, 1.2, level: z);
      }
      b.window('$t-wl', Offset(-hw, -hd / 2), 90, 1.0, level: z);
      b.window('$t-wr', Offset(hw, -hd / 2), 90, 1.0, level: z);
      if (f == 0) {
        b.opening(
          '$t-front',
          ArchitectureType.doorClosed,
          Offset(-hw / 2, hd),
          0,
          0.9,
          head: 2.1,
          level: z,
        );
        b.window('$t-wf', Offset(hw / 4, hd), 0, 1.4, level: z);
      } else {
        b.window('$t-wf0', Offset(-hw / 2, hd), 0, 1.2, level: z);
        b.window('$t-wf1', Offset(hw / 4, hd), 0, 1.2, level: z);
      }
      // El suelo: el de la planta baja, de madera; los de arriba, un
      // nivel con su nombre.
      if (f == 0) {
        b.slab(
          '$t-floor',
          Rect.fromLTRB(-hw, -hd, hw, hd),
          top: 0,
          thick: 0.1,
          mat: 'wood-floor-oak',
        );
      } else {
        b.slab(
          '$t-floor',
          Rect.fromLTRB(-hw, -hd, hw, hd),
          top: z,
          thick: PlanLevels.defaultSlabThickM,
          mat: 'wood-floor-oak',
          name: 'Planta $f',
        );
      }
      if (f + 1 < floors) {
        b.stair(
          '$t-stair',
          Offset(stairX, hd - 0.4),
          Offset(stairX, hd - 0.4 - run),
          rise: storey,
          width: stairW,
          level: z,
        );
      }
    }
    // El tejado, sobre una losa encima de la última planta.
    final roof = b.s('roof');
    final top = b.volume(
      'roof',
      Rect.fromLTRB(-hw, -hd, hw, hd),
      height: 0.2,
      level: floors * storey,
      mat: 'plaster-raw',
    );
    if (roof != 'flat') {
      top.props[ArchSolid.roofKey] = ArchRoof(
        kind: roof == 'hip' ? ArchRoofKind.hip : ArchRoofKind.gable,
        riseM: (math.min(w, d) * 0.3 * 100).round() / 100,
        ridgeDeg: w >= d ? 0 : 90,
        overhangM: 0.4,
        mat: 'stone-slate-roof',
      ).toJson();
    }
  }

  static void _room(_Builder b) {
    final w = b.n('widthM'), d = b.n('depthM'), h = b.n('heightM');
    final type = b.s('type');
    final hw = w / 2, hd = d / 2;
    for (final (i, (a, c)) in [
      (Offset(-hw, -hd), Offset(hw, -hd)),
      (Offset(hw, -hd), Offset(hw, hd)),
      (Offset(hw, hd), Offset(-hw, hd)),
      (Offset(-hw, hd), Offset(-hw, -hd)),
    ].indexed) {
      b.wall(
        'w$i',
        a,
        c,
        height: h,
        thick: 0.12,
        mat: switch (type) {
          'bathroom' => 'tile-light',
          'bar' => 'wood-painted',
          _ => 'paint-white',
        },
      );
    }
    b.opening(
      'door',
      type == 'bar' ? ArchitectureType.doubleDoor : ArchitectureType.doorClosed,
      Offset(hw - 0.8, hd),
      0,
      type == 'bar' ? 1.6 : _door.w,
      head: _door.h,
    );
    b.window('win', Offset(0, -hd), 0, math.min(1.6, w * 0.35));
    b.slab(
      'floor',
      Rect.fromLTRB(-hw, -hd, hw, hd),
      top: 0,
      thick: 0.05,
      mat: switch (type) {
        'kitchen' || 'bathroom' => 'tile-light',
        'bar' => 'wood-floor-dark',
        _ => 'wood-floor-oak',
      },
    );
    // Los muebles, contra las paredes y dejando paso hasta la puerta.
    final backY = -hd + 0.06;
    switch (type) {
      case 'bedroom':
        b.prop('bed', PropType.bed, Offset(0, backY + 1.0), 1.5, 2.0, 0.55);
        b.prop(
          'ns0',
          PropType.rectangle,
          Offset(-1.05, backY + 0.22),
          0.45,
          0.4,
          0.5,
        );
        b.prop(
          'ns1',
          PropType.rectangle,
          Offset(1.05, backY + 0.22),
          0.45,
          0.4,
          0.5,
        );
        b.volume(
          'wardrobe',
          _box(Offset(-hw + 0.36, hd - 1.4), 0.6, 1.8),
          height: 2.1,
          mat: 'wood-planks',
        );
      case 'kitchen':
        b.volume(
          'counter',
          _box(Offset(0, backY + 0.3), w - 0.3, 0.6),
          height: 0.9,
          mat: 'stone-marble',
        );
        b.volume(
          'fridge',
          _box(Offset(hw - 0.45, -hd / 3), 0.7, 0.7),
          height: 1.85,
          mat: 'metal-brushed',
        );
        b.prop('table', PropType.table, Offset(-0.2, hd / 3), 1.2, 0.8, 0.75);
        for (final (i, p) in [
          Offset(-0.6, hd / 3 - 0.6),
          Offset(0.2, hd / 3 - 0.6),
          Offset(-0.6, hd / 3 + 0.6),
          Offset(0.2, hd / 3 + 0.6),
        ].indexed) {
          b.prop('chair$i', PropType.chair, p, 0.45, 0.5, 0.9);
        }
      case 'bathroom':
        b.volume(
          'bath',
          _box(Offset(-hw + 0.95, backY + 0.38), 1.7, 0.75),
          height: 0.55,
          mat: 'tile-light',
        );
        b.volume(
          'wc',
          _box(Offset(hw - 0.45, backY + 0.33), 0.4, 0.65),
          height: 0.75,
          mat: 'paint-white',
        );
        b.volume(
          'sink',
          _box(Offset(-hw + 0.4, hd / 3), 0.45, 0.6),
          height: 0.85,
          mat: 'paint-white',
        );
      case 'living':
        b.prop('sofa', PropType.sofa, Offset(0, backY + 0.5), 2.0, 0.9, 0.85);
        b.prop(
          'coffee',
          PropType.table,
          Offset(0, backY + 1.6),
          1.1,
          0.6,
          0.45,
        );
        b.prop(
          'arm0',
          PropType.chair,
          Offset(-1.4, backY + 1.6),
          0.8,
          0.8,
          0.85,
        );
        b.volume(
          'tv',
          _box(Offset(0, hd - 0.3), 1.6, 0.45),
          height: 0.5,
          mat: 'wood-floor-dark',
        );
      case 'bar':
        b.volume(
          'counter',
          _box(Offset(-hw * 0.2, -hd * 0.25), w * 0.6, 0.6),
          height: 1.1,
          mat: 'wood-planks',
        );
        b.volume(
          'shelves',
          _box(Offset(-hw * 0.2, backY + 0.18), w * 0.6, 0.35),
          height: 2.0,
          mat: 'wood-floor-dark',
        );
        final stools = math.max(2, (w * 0.6 / 0.7).floor());
        for (var i = 0; i < stools; i++) {
          b.prop(
            'stool$i',
            PropType.chair,
            Offset(
              -hw * 0.2 - w * 0.3 + (i + 0.5) * w * 0.6 / stools,
              -hd * 0.25 + 0.65,
            ),
            0.4,
            0.4,
            0.75,
          );
        }
        b.prop(
          't0',
          PropType.table,
          Offset(hw * 0.55, hd * 0.45),
          0.7,
          0.7,
          0.75,
        );
        b.prop(
          't1',
          PropType.table,
          Offset(-hw * 0.55, hd * 0.45),
          0.7,
          0.7,
          0.75,
        );
    }
  }

  static Rect _box(Offset c, double w, double d) =>
      Rect.fromCenter(center: c, width: w, height: d);

  // ── Edificio y puente ────────────────────────────────────────────────

  static void _building(_Builder b) {
    final w = b.n('widthM'), d = b.n('depthM');
    final floors = b.n('floors').round();
    final storey = b.n('storeyM');
    final ground = math.max(storey, 4.0);
    final module = b.n('moduleM');
    final shop = b.flag('shop'), balconies = b.flag('balconies');
    final mat = b.s('wallMat');
    final hw = w / 2, hd = d / 2;
    final modules = math.max(1, (w / module).floor());
    final step = w / modules;
    double floorZ(int f) => f == 0 ? 0 : ground + (f - 1) * storey;
    double heightOf(int f) => f == 0 ? ground : storey;
    for (var f = 0; f < floors; f++) {
      final z = floorZ(f), h = heightOf(f);
      final t = 'p$f';
      for (final (i, (a, c)) in [
        (Offset(-hw, -hd), Offset(hw, -hd)),
        (Offset(hw, -hd), Offset(hw, hd)),
        (Offset(hw, hd), Offset(-hw, hd)),
        (Offset(-hw, hd), Offset(-hw, -hd)),
      ].indexed) {
        b.wall('$t-w$i', a, c, level: z, height: h, thick: 0.3, mat: mat);
      }
      for (var m = 0; m < modules; m++) {
        final x = -hw + (m + 0.5) * step;
        b.window(
          '$t-b$m',
          Offset(x, -hd),
          0,
          math.min(1.2, step - 0.6),
          level: z,
        );
        if (f == 0) {
          final entrance = m == modules ~/ 2;
          if (entrance) {
            b.opening(
              '$t-door',
              ArchitectureType.doubleDoor,
              Offset(x, hd),
              0,
              math.min(1.6, step - 0.4),
              head: 2.6,
              level: z,
            );
          } else if (shop) {
            // Escaparate: de casi el suelo a casi el techo.
            b.window(
              '$t-f$m',
              Offset(x, hd),
              0,
              step - 0.5,
              level: z,
              sill: 0.3,
              head: ground - 0.6,
            );
          } else {
            b.window(
              '$t-f$m',
              Offset(x, hd),
              0,
              math.min(1.2, step - 0.6),
              level: z,
            );
          }
          continue;
        }
        b.window(
          '$t-f$m',
          Offset(x, hd),
          0,
          math.min(1.2, step - 0.6),
          level: z,
          sill: balconies ? 0 : 0.9,
          head: 2.2,
        );
        if (balconies) {
          // Balcón: una losa volada y su barandilla.
          final bw = math.min(step - 0.4, 2.4);
          b.slab(
            '$t-bal$m',
            Rect.fromLTRB(x - bw / 2, hd, x + bw / 2, hd + 1.0),
            top: z,
            thick: 0.15,
            mat: 'concrete-smooth',
          );
          final rail = b.sweep(
            '$t-rail$m',
            Offset(x - bw / 2, hd + 0.95),
            Offset(x + bw / 2, hd + 0.95),
            SweepKind.railing,
            level: z,
          );
          rail.props[ArchSweep.heightKey] = 1.0;
        }
      }
      if (f > 0) {
        b.slab(
          '$t-floor',
          Rect.fromLTRB(-hw, -hd, hw, hd),
          top: z,
          thick: PlanLevels.defaultSlabThickM,
          mat: 'concrete-smooth',
          name: 'Planta $f',
        );
      }
    }
    // Cubierta plana con su peto.
    final topZ = floorZ(floors);
    b.slab(
      'roof',
      Rect.fromLTRB(-hw, -hd, hw, hd),
      top: topZ + 0.3,
      thick: 0.3,
      mat: 'concrete-smooth',
    );
  }

  /// Una calle con perfil (calzada, aceras y farolas) y una fila de
  /// edificios a cada lado, de fachada hacia la calle. Cada edificio
  /// cambia un poco de altura y de fachada para que no salgan todos
  /// iguales.
  static void _street(_Builder b) {
    final len = b.n('lengthM'), road = b.n('roadM'), walk = b.n('walkM');
    final front = b.n('frontM'), floors = b.n('floors').round();
    final street = b.add(
      PlanSegment.create(
        start: b.at(Offset(-len / 2, 0)),
        end: b.at(Offset(len / 2, 0)),
      ),
      'street',
    );
    street.props['kind'] = PlanSegment.kindStreet;
    StreetProfile(
      roadM: road,
      walkLeftM: walk,
      walkRightM: walk,
      lampStyle: StreetLamp.stylePole,
    ).writeTo(street);
    const mats = ['brick-tan', 'paint-cream', 'brick-old', 'concrete-smooth'];
    final n = math.max(1, (len / front).floor());
    final w = len / n;
    const depth = 12.0;
    final line = road / 2 + walk;
    for (final (side, flip) in [
      ('n', false),
      if (b.flag('both')) ('s', true),
    ]) {
      for (var k = 0; k < n; k++) {
        final i = k + (flip ? 1 : 0);
        final sub = b.child(
          '$side$k-',
          Offset(
            -len / 2 + (k + 0.5) * w,
            flip ? line + depth / 2 : -line - depth / 2,
          ),
          flip: flip,
          params: {
            'widthM': w - 0.2,
            'depthM': depth,
            'floors': math
                .max(1, floors + (i % 3 == 1 ? 1 : (i % 3 == 2 ? -1 : 0)))
                .toDouble(),
            'storeyM': 3.0,
            'moduleM': 3.0,
            'shop': true,
            'balconies': i.isEven,
            'wallMat': mats[i % mats.length],
          },
        );
        _building(sub);
      }
    }
  }

  static void _bridge(_Builder b) {
    final len = b.n('lengthM'), w = b.n('widthM'), h = b.n('heightM');
    if (b.s('type') == 'arch') {
      // Sobre el arco, un tablero sin pilas y sus barandillas.
      b.slab(
        'deck',
        Rect.fromLTRB(-len / 2, -w / 2, len / 2, w / 2),
        top: h,
        thick: 0.6,
        mat: 'stone-paving',
      );
      for (final (j, y) in [-w / 2 + 0.15, w / 2 - 0.15].indexed) {
        final rail = b.sweep(
          'rail$j',
          Offset(-len / 2, y),
          Offset(len / 2, y),
          SweepKind.railing,
          level: h,
        );
        rail.props[ArchSweep.heightKey] = 1.0;
      }
      _arch(b, len, w, h);
    } else {
      final deck = b.sweep(
        'deck',
        Offset(-len / 2, 0),
        Offset(len / 2, 0),
        SweepKind.deck,
      );
      deck.props
        ..[ArchSweep.widthKey] = w
        ..[ArchSweep.baseKey] = h
        ..[ArchSweep.everyKey] = b.n('spanM');
    }
    if (!b.flag('river')) return;
    // El río: un cauce que baja en el medio, con agua.
    final across = math.max(30.0, w * 4);
    b.terrain(
      'river',
      Rect.fromLTRB(-len / 2 - 6, -across / 2, len / 2 + 6, across / 2),
      (p) {
        final t = (p.dx.abs() / (len * 0.35)).clamp(0.0, 1.0);
        return -2.5 * (1 - t * t * (3 - 2 * t));
      },
      paint: (p, z) => z < -1.2 ? 'earth' : 'grass',
      water: -0.6,
    );
  }

  /// Un arco de piedra bajo el tablero: dovelas que siguen una parábola
  /// de estribo a estribo y montantes que llevan el tablero.
  static void _arch(_Builder b, double len, double w, double h) {
    final span = len * 0.8, rise = math.max(0.5, h - 0.9);
    double zAt(double x) => rise * (1 - math.pow(2 * x / span, 2).toDouble());
    const n = 24;
    final ds = span / n;
    for (var k = 0; k < n; k++) {
      final x = -span / 2 + (k + 0.5) * ds;
      final z = zAt(x);
      b.volume(
        'arch$k',
        Rect.fromCenter(
          center: Offset(x, 0),
          width: ds + 0.08,
          height: w * 0.7,
        ),
        height: 0.6,
        mat: 'stone-rock',
        level: math.max(0.0, z - 0.3),
      );
    }
    // Montantes cada 4 m entre el arco y el tablero.
    final posts = math.max(2, (span / 4).floor());
    for (var k = 1; k < posts; k++) {
      final x = -span / 2 + k * span / posts;
      final z = zAt(x) + 0.3;
      if (h - 0.6 - z < 0.3) continue;
      for (final (j, y) in [-w * 0.25, w * 0.25].indexed) {
        b.pillar(
          'post$k-$j',
          Offset(x, y),
          size: 0.4,
          height: h - 0.6 - z,
          level: z,
        );
      }
    }
    // Estribos en las dos puntas.
    for (final (j, x) in [-span / 2 - 1, span / 2 + 1].indexed) {
      b.volume(
        'abut$j',
        Rect.fromCenter(center: Offset(x, 0), width: 2, height: w * 0.8),
        height: math.max(0.5, h - 0.6),
        mat: 'stone-rock',
      );
    }
  }

  // ── Estación y vagón ─────────────────────────────────────────────────

  static void _station(_Builder b) {
    final len = b.n('lengthM'), hp = b.n('platformM'), wp = b.n('widthM');
    final tracks = b.n('tracks').round();
    final under = b.flag('underpass');
    // El paso subterráneo: una escalera que baja del andén a un túnel
    // que cruza bajo las vías.
    const depth = 3.2, stairW = 2.0;
    final rise = depth + hp;
    final run = ((rise / 0.17).ceil() - 1) * 0.29;
    final xs = len * 0.2 - run / 2, xe = xs + run;
    if (under && run < len * 0.6 && wp >= stairW + 1) {
      for (final (tag, r) in [
        ('platform', Rect.fromLTRB(-len / 2, -wp / 2, xs, wp / 2)),
        ('platform-b', Rect.fromLTRB(xe, -wp / 2, len / 2, wp / 2)),
        ('platform-c', Rect.fromLTRB(xs, -wp / 2, xe, -stairW / 2 - 0.1)),
        ('platform-d', Rect.fromLTRB(xs, stairW / 2 + 0.1, xe, wp / 2)),
      ]) {
        b.volume(tag, r, height: hp, mat: 'stone-paving');
      }
      b.stair(
        'down',
        Offset(xs, 0),
        Offset(xe, 0),
        rise: rise,
        width: stairW,
        level: -depth,
      );
      // El túnel, a lo ancho de las vías.
      final reach = wp / 2 + (tracks > 1 ? 5.0 : 2.5);
      final y0 = tracks > 1 ? -reach : -wp / 2, y1 = reach;
      b.slab(
        'tunnel-floor',
        Rect.fromLTRB(xs - 3, y0, xs, y1),
        top: -depth,
        thick: 0.3,
        mat: 'tile-light',
      );
      b.slab(
        'tunnel-roof',
        Rect.fromLTRB(xs - 3.2, y0, xs + 0.2, y1),
        top: 0,
        thick: 0.4,
        mat: 'concrete-smooth',
      );
      for (final (j, y) in [y0, y1].indexed) {
        b.wall(
          'tunnel-e$j',
          Offset(xs - 3, y),
          Offset(xs, y),
          level: -depth,
          height: depth - 0.4,
          thick: 0.25,
          mat: 'tile-light',
        );
      }
      for (final (j, x) in [xs - 3, xs].indexed) {
        b.wall(
          'tunnel-w$j',
          Offset(x, y0),
          Offset(x, y1),
          level: -depth,
          height: depth - 0.4,
          thick: 0.25,
          mat: 'tile-light',
        );
      }
      b.opening(
        'tunnel-door',
        ArchitectureType.opening,
        Offset(xs, 0),
        90,
        stairW,
        head: depth - 0.45,
        level: -depth,
      );
    } else {
      b.volume(
        'platform',
        Rect.fromLTRB(-len / 2, -wp / 2, len / 2, wp / 2),
        height: hp,
        mat: 'stone-paving',
      );
    }
    // Del borde del andén al eje de la vía, 1,65 m.
    final ys = [wp / 2 + 1.65, if (tracks > 1) -wp / 2 - 1.65];
    for (final (i, y) in ys.indexed) {
      b.sweep(
        'track$i',
        Offset(-len / 2 - 15, y),
        Offset(len / 2 + 15, y),
        SweepKind.track,
      );
      if (b.flag('catenary')) {
        b.sweep(
          'wire$i',
          Offset(-len / 2 - 15, y),
          Offset(len / 2 + 15, y),
          SweepKind.catenary,
        );
      }
    }
    if (b.flag('canopy')) {
      // Marquesina: pilares en el eje del andén y la cubierta encima.
      final n = math.max(2, (len * 0.8 / 8).round() + 1);
      for (var i = 0; i < n; i++) {
        final x = -len * 0.4 + i * len * 0.8 / (n - 1);
        b.pillar('col$i', Offset(x, 0), size: 0.3, height: 3.6, level: hp);
      }
      b.slab(
        'canopy',
        Rect.fromLTRB(-len * 0.42, -wp * 0.45, len * 0.42, wp * 0.45),
        top: hp + 3.8,
        thick: 0.2,
        mat: 'metal-corrugated',
      );
    }
    // Escalera de subida al andén por una punta.
    final up = math.max(1.0, ((hp / 0.16).ceil() - 1) * 0.3);
    b.stair(
      'access',
      Offset(-len / 2 - up, 0),
      Offset(-len / 2, 0),
      rise: hp,
      width: math.min(2.4, wp - 0.6),
    );
  }

  /// El vagón por dentro: bastidor, suelo, paredes con ventanas en serie,
  /// puertas, testeros con su paso, techo en bóveda y los asientos y las
  /// mesas como muebles sueltos (para sentar a los personajes).
  static void _carriage(_Builder b) {
    final len = b.n('lengthM'), w = b.n('widthM'), floor = b.n('floorM');
    final pitch = b.n('pitchM');
    final layout = b.s('layout');
    final doors = b.flag('doors');
    final hl = len / 2, hw = w / 2;
    const wallT = 0.08, inner = 2.15, vestibule = 2.0;
    // Bajo el piso, el bastidor; encima, el suelo.
    b.volume(
      'chassis',
      Rect.fromLTRB(-hl + 0.6, -hw + 0.25, hl - 0.6, hw - 0.25),
      height: math.max(0.05, floor - 0.35),
      mat: 'metal-brushed',
      level: 0.35,
    );
    b.slab(
      'floor',
      Rect.fromLTRB(-hl, -hw, hl, hw),
      top: floor,
      thick: 0.12,
      mat: 'carpet-dark',
    );
    // Paredes y testeros.
    for (final (i, (a, c)) in [
      (Offset(-hl, -hw), Offset(hl, -hw)),
      (Offset(hl, -hw), Offset(hl, hw)),
      (Offset(hl, hw), Offset(-hl, hw)),
      (Offset(-hl, hw), Offset(-hl, -hw)),
    ].indexed) {
      b.wall(
        'w$i',
        a,
        c,
        level: floor,
        height: inner,
        thick: wallT,
        mat: 'paint-white',
      );
    }
    // El paso entre vagones, en cada testero.
    for (final (i, x) in [-hl, hl].indexed) {
      b.opening(
        'gang$i',
        ArchitectureType.doorClosed,
        Offset(x, 0),
        90,
        0.9,
        head: 1.95,
        level: floor,
      );
    }
    // Puertas a los lados, junto a cada extremo.
    final seatFrom = -hl + vestibule, seatTo = hl - vestibule;
    if (doors) {
      for (final (i, x) in [-hl + vestibule / 2, hl - vestibule / 2].indexed) {
        for (final (j, y) in [-hw, hw].indexed) {
          b.opening(
            'door$i$j',
            ArchitectureType.doubleDoor,
            Offset(x, y),
            0,
            1.3,
            head: 1.95,
            level: floor,
          );
        }
      }
    }
    // Ventanas en serie entre las puertas.
    final windows = math.max(1, ((seatTo - seatFrom) / 1.9).floor());
    final step = (seatTo - seatFrom) / windows;
    for (var k = 0; k < windows; k++) {
      final x = seatFrom + (k + 0.5) * step;
      for (final (j, y) in [-hw, hw].indexed) {
        b.window(
          'win$k$j',
          Offset(x, y),
          0,
          math.min(1.4, step - 0.35),
          level: floor,
          sill: 0.75,
          head: 1.75,
        );
      }
    }
    // El techo en bóveda.
    final roof = b.volume(
      'roof',
      Rect.fromLTRB(-hl, -hw, hl, hw),
      height: 0.06,
      mat: 'metal-brushed',
      level: floor + inner,
    );
    roof.props[ArchSolid.roofKey] = ArchRoof(
      kind: ArchRoofKind.vault,
      riseM: 0.35,
      ridgeDeg: 0,
      overhangM: 0.05,
      mat: 'metal-brushed',
    ).toJson();
    // Asientos a cada lado del pasillo: de dos plazas, contra la pared.
    final seatD = 0.55, seatW = math.min(1.05, (w - 2 * wallT - 0.6) / 2);
    final sideY = [-(hw - wallT - seatW / 2), hw - wallT - seatW / 2];
    void bench(String tag, Offset c, double deg, double width, double depth) {
      final el = b.prop(
        tag,
        PropType.sofa,
        c,
        width,
        depth,
        1.05,
        level: floor,
        deg: deg,
      );
      el.props[PlanSeats.seatHeightKey] = 0.45;
      el.customName = 'Asiento';
    }

    switch (layout) {
      case 'metro':
        // Bancos corridos contra las paredes, de cara al pasillo.
        const benchW = 0.5;
        for (final (j, y) in [
          -(hw - wallT - benchW / 2),
          hw - wallT - benchW / 2,
        ].indexed) {
          for (var k = 0; k < windows; k++) {
            final x = seatFrom + (k + 0.5) * step;
            bench(
              'seat$k-$j',
              Offset(x, y),
              j == 0 ? 180 : 0,
              step - 0.3,
              benchW,
            );
          }
        }
      case 'rows':
        // Todos mirando hacia delante (a la derecha del lienzo).
        final n = math.max(1, ((seatTo - seatFrom) / pitch).floor());
        for (var k = 0; k < n; k++) {
          final x = seatFrom + (k + 0.5) * (seatTo - seatFrom) / n;
          for (final (j, y) in sideY.indexed) {
            bench('seat$k-$j', Offset(x, y), 90, seatW, seatD);
          }
        }
      default:
        // Enfrentados de dos en dos, con una mesa entre los dos.
        final bay = pitch + seatD + 0.25;
        final n = math.max(1, ((seatTo - seatFrom) / bay).floor());
        final pad = (seatTo - seatFrom - n * bay) / 2;
        for (var k = 0; k < n; k++) {
          final x0 = seatFrom + pad + k * bay + seatD / 2 + 0.12;
          final x1 = x0 + pitch;
          for (final (j, y) in sideY.indexed) {
            bench('seat$k-$j-a', Offset(x0, y), 90, seatW, seatD);
            bench('seat$k-$j-b', Offset(x1, y), 270, seatW, seatD);
            final table = b.prop(
              'table$k-$j',
              PropType.table,
              Offset((x0 + x1) / 2, y + (j == 0 ? -0.05 : 0.05)),
              math.max(0.4, pitch - seatD - 0.2),
              seatW - 0.15,
              0.74,
              level: floor,
            );
            table.customName = 'Mesa';
          }
        }
    }
  }

  // ── Naturaleza ───────────────────────────────────────────────────────

  static void _mountain(_Builder b) {
    final size = b.n('sizeM'), peak = b.n('peakM');
    final seed = b.n('seed').round();
    final r = size / 2;
    double noise(double x, double y) {
      // Ruido de valores en tres escalas: siempre el mismo para la misma
      // forma.
      double lattice(int i, int j) {
        final h = math.sin(i * 127.1 + j * 311.7 + seed * 74.7) * 43758.5453;
        return h - h.floorToDouble();
      }

      double smooth(double x, double y) {
        final i = x.floor(), j = y.floor();
        final u = x - i, v = y - j;
        final su = u * u * (3 - 2 * u), sv = v * v * (3 - 2 * v);
        final a = lattice(i, j), c = lattice(i + 1, j);
        final e = lattice(i, j + 1), f = lattice(i + 1, j + 1);
        return (a + (c - a) * su) * (1 - sv) + (e + (f - e) * su) * sv;
      }

      var sum = 0.0, amp = 0.55, freq = 3 / size;
      for (var o = 0; o < 3; o++) {
        sum += amp * smooth(x * freq, y * freq);
        amp *= 0.5;
        freq *= 2.1;
      }
      return sum;
    }

    b.terrain(
      'mountain',
      Rect.fromLTRB(-r, -r, r, r),
      (p) {
        final d = (p.distance / r).clamp(0.0, 1.0);
        final dome = math.pow(math.cos(d * math.pi / 2), 1.6).toDouble();
        return peak * dome * (0.45 + 0.75 * noise(p.dx, p.dy));
      },
      paint: (p, z) {
        final t = z / peak;
        return t > 0.62 ? 'stone-rock' : (t > 0.32 ? 'earth' : 'grass');
      },
    );
  }

  static void _beach(_Builder b) {
    final w = b.n('widthM'), d = b.n('depthM');
    final walk = b.n('promenadeM'), wall = b.n('wallM');
    final top = -d / 2, edge = top + walk;
    b.terrain(
      'beach',
      Rect.fromLTRB(-w / 2, top, w / 2, d / 2),
      (p) {
        if (p.dy <= edge) return wall;
        // Del pie del muro, la arena seca baja suave hasta la orilla
        // (a media playa) y luego se mete en el mar.
        final t = ((p.dy - edge) / (d / 2 - edge)).clamp(0.0, 1.0);
        return t < 0.55 ? 0.8 * (1 - t / 0.55) : -1.5 * (t - 0.55) / 0.45;
      },
      paint: (p, z) => p.dy <= edge ? 'stone-paving' : 'sand',
      water: 0,
    );
    final rail = b.sweep(
      'rail',
      Offset(-w / 2, edge - 0.1),
      Offset(w / 2, edge - 0.1),
      SweepKind.railing,
      level: wall,
    );
    rail.props[ArchSweep.heightKey] = 1.0;
    final trees = math.max(2, (w / 12).floor());
    for (var i = 0; i < trees; i++) {
      final x = -w / 2 + (i + 0.5) * w / trees;
      b.prop(
        'palm$i',
        PropType.tree,
        Offset(x, top + walk / 2),
        1.6,
        1.6,
        6,
        level: wall,
      );
    }
  }
}

/// Ayuda para generar: medidas en metros respecto al centro de la receta
/// (y hacia abajo, como el lienzo), y cada pieza con su marca.
class _Builder {
  final PlanElement recipe;
  final String uid;
  final double mpu;
  final List<PlanElement> out;

  /// Para una receta dentro de otra (los edificios de una calle): dónde
  /// está su centro, si va del revés (de cara al otro lado), sus medidas
  /// y la marca que antecede a las de sus piezas.
  final Offset origin;
  final bool flip;
  final Map<String, Object> params;
  final String prefix;

  _Builder(
    this.recipe,
    this.uid,
    this.mpu, {
    List<PlanElement>? out,
    this.origin = Offset.zero,
    this.flip = false,
    this.params = const {},
    this.prefix = '',
  }) : out = out ?? <PlanElement>[];

  _Builder child(
    String prefix,
    Offset origin, {
    bool flip = false,
    Map<String, Object> params = const {},
  }) => _Builder(
    recipe,
    uid,
    mpu,
    out: out,
    origin: this.origin + origin,
    flip: flip,
    params: params,
    prefix: this.prefix + prefix,
  );

  double n(String k) =>
      (params[k] as num?)?.toDouble() ?? ArchRecipe.number(recipe, k);
  String s(String k) =>
      params[k] as String? ?? ArchRecipe.value(recipe, k) as String;
  bool flag(String k) =>
      params[k] as bool? ?? ArchRecipe.value(recipe, k) as bool;

  Offset at(Offset m) =>
      recipe.position + (origin + (flip ? Offset(m.dx, -m.dy) : m)) / mpu;

  PlanElement add(PlanElement el, String tag, {double level = 0}) {
    el.props[LightOverrides.uidKey] = '$uid-$prefix$tag';
    el.props[ArchRecipe.ownerKey] = uid;
    PlanLevel.set(el, (level * 1000).round() / 1000);
    out.add(el);
    return el;
  }

  void wall(
    String tag,
    Offset a,
    Offset b, {
    double level = 0,
    required double height,
    required double thick,
    required String mat,
  }) {
    final el = PlanSegment.create(start: at(a), end: at(b));
    el.props
      ..[PlanSegment.heightKey] = height
      ..[PlanSegment.thicknessKey] = thick
      ..[ArchMaterials.key] = mat;
    add(el, tag, level: level);
  }

  /// Un hueco centrado en [c], a lo largo de una pared girada [deg].
  void opening(
    String tag,
    ArchitectureType type,
    Offset c,
    double deg,
    double widthM, {
    double sill = 0,
    double head = 2.1,
    double level = 0,
  }) => add(
    PlanElement(
      id: 0,
      type: ElementType.wall,
      position: at(c),
      rotation: deg,
      label: type.dbValue,
      props: {
        PlanOpening.widthKey: widthM / mpu,
        PlanOpening.sillKey: sill,
        PlanOpening.headKey: head,
      },
    ),
    tag,
    level: level,
  );

  void window(
    String tag,
    Offset c,
    double deg,
    double widthM, {
    double level = 0,
    double sill = 0.9,
    double head = 2.1,
  }) => opening(
    tag,
    ArchitectureType.window,
    c,
    deg,
    widthM,
    sill: sill,
    head: head,
    level: level,
  );

  List<Offset> _outline(Rect r) => [
    Offset(-r.width / 2, -r.height / 2),
    Offset(r.width / 2, -r.height / 2),
    Offset(r.width / 2, r.height / 2),
    Offset(-r.width / 2, r.height / 2),
  ];

  PlanElement slab(
    String tag,
    Rect r, {
    required double top,
    required double thick,
    required String mat,
    String? name,
  }) {
    final el = ArchSolid.create(RigType.slab, at(r.center), _outline(r));
    el.props
      ..[ArchSolid.topKey] = (top * 1000).round() / 1000
      ..[ArchSolid.thickKey] = thick
      ..[ArchMaterials.key] = mat;
    if (name != null) el.props[PlanLevels.nameKey] = name;
    return add(el, tag);
  }

  PlanElement volume(
    String tag,
    Rect r, {
    required double height,
    required String mat,
    double level = 0,
  }) {
    final el = ArchSolid.create(RigType.volume, at(r.center), _outline(r));
    el.props
      ..[ArchSolid.heightKey] = height
      ..[ArchMaterials.key] = mat;
    return add(el, tag, level: level);
  }

  void pillar(
    String tag,
    Offset p, {
    required double size,
    required double height,
    double level = 0,
  }) => add(
    PlanPillar.create(at(p), sizeM: size, heightM: height),
    tag,
    level: level,
  );

  void stair(
    String tag,
    Offset from,
    Offset to, {
    required double rise,
    required double width,
    double level = 0,
  }) {
    final el = ArchStair.create(at(from), at(to), mpu);
    el.props
      ..[ArchStair.riseKey] = (rise * 100).round() / 100
      ..[ArchStair.widthKey] = width;
    add(el, tag, level: level);
  }

  PlanElement sweep(
    String tag,
    Offset from,
    Offset to,
    SweepKind kind, {
    double level = 0,
  }) => add(ArchSweep.create(at(from), at(to), kind: kind), tag, level: level);

  PlanElement prop(
    String tag,
    PropType type,
    Offset c,
    double w,
    double d,
    double h, {
    double level = 0,
    double deg = 0,
  }) => add(
    PlanElement(
      id: 0,
      type: ElementType.prop,
      position: at(c),
      rotation: deg,
      label: type.dbValue,
      props: {
        if (type == PropType.tree) ...{
          LightScene.sizeKey: w / 2,
        } else ...{
          LightScene.widthKey: w,
          LightScene.depthKey: d,
        },
        LightScene.heightKey: h,
      },
    ),
    tag,
    level: level,
  );

  /// Un terreno en [r] con la cota que da [height] y el material que da
  /// [paint] en cada sitio (metros respecto al centro de la receta).
  void terrain(
    String tag,
    Rect r,
    double Function(Offset p) height, {
    String Function(Offset p, double z)? paint,
    double? water,
  }) {
    final el = ArchTerrain.create(at(r.topLeft), at(r.bottomRight), mpu);
    final c = ArchTerrain.cols(el), rows = ArchTerrain.rows(el);
    final cell = ArchTerrain.cellM(el);
    final o = r.topLeft;
    ArchTerrain.setHeights(el, [
      for (var j = 0; j <= rows; j++)
        for (var i = 0; i <= c; i++) height(o + Offset(i * cell, j * cell)),
    ]);
    if (paint != null) {
      final hs = ArchTerrain.heights(el);
      final mats = <String>[];
      final cells = <int>[];
      for (var j = 0; j < rows; j++) {
        for (var i = 0; i < c; i++) {
          final z = (hs[j * (c + 1) + i] + hs[(j + 1) * (c + 1) + i + 1]) / 2;
          final m = paint(o + Offset((i + 0.5) * cell, (j + 0.5) * cell), z);
          var k = mats.indexOf(m);
          if (k < 0) {
            mats.add(m);
            k = mats.length - 1;
          }
          cells.add(k);
        }
      }
      el.props
        ..[ArchTerrain.matsKey] = mats
        ..[ArchTerrain.paintKey] = cells;
    }
    if (water != null) ArchTerrain.setWater(el, water);
    add(el, tag);
  }
}
