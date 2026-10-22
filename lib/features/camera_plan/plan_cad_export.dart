import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter/painting.dart';
import 'package:xml/xml.dart';

import 'camera_plan_constants.dart';
import 'camera_plan_element_model.dart';
import 'light/light_scene.dart';
import 'light/plan_light.dart';
import 'light_beam.dart';
import 'plan_elevation.dart';
import 'plan_gear_list.dart';
import 'plan_opening.dart';
import 'plan_segment.dart';
import 'plan_terrain_painter.dart';

/// Escribe un DXF R12 en ASCII: el formato que abre cualquier programa de
/// CAD (AutoCAD, Vectorworks, LibreCAD, Rhino). En metros, con capas por
/// tipo de pieza.
class _Dxf {
  final _out = StringBuffer();
  final Set<String> layers;

  _Dxf(this.layers);

  void _pair(int code, Object value) {
    _out
      ..writeln(code)
      // Sin «-0.0000»: algunos lectores lo tropiezan.
      ..writeln(
        value is double ? (value == 0 ? 0.0 : value).toStringAsFixed(4) : value,
      );
  }

  void line(String layer, Offset a, Offset b) {
    _pair(0, 'LINE');
    _pair(8, layer);
    _pair(10, a.dx);
    _pair(20, a.dy);
    _pair(30, 0.0);
    _pair(11, b.dx);
    _pair(21, b.dy);
    _pair(31, 0.0);
  }

  void polyline(String layer, List<Offset> points, {bool closed = false}) {
    for (var i = 0; i < points.length - 1; i++) {
      line(layer, points[i], points[i + 1]);
    }
    if (closed && points.length > 2) line(layer, points.last, points.first);
  }

  void circle(String layer, Offset c, double r) {
    _pair(0, 'CIRCLE');
    _pair(8, layer);
    _pair(10, c.dx);
    _pair(20, c.dy);
    _pair(30, 0.0);
    _pair(40, r);
  }

  void text(String layer, Offset at, String value, {double height = 0.15}) {
    if (value.trim().isEmpty) return;
    _pair(0, 'TEXT');
    _pair(8, layer);
    _pair(10, at.dx);
    _pair(20, at.dy);
    _pair(30, 0.0);
    _pair(40, height);
    // R12 no lleva Unicode: se quitan acentos y lo que no sea ASCII.
    _pair(1, _ascii(value.replaceAll('\n', ' · ')));
  }

  static String _ascii(String s) {
    const map = {
      'á': 'a', 'é': 'e', 'í': 'i', 'ó': 'o', 'ú': 'u', 'ü': 'u', 'ñ': 'n', //
      'Á': 'A', 'É': 'E', 'Í': 'I', 'Ó': 'O', 'Ú': 'U', 'Ñ': 'N', '·': '-',
      '°': ' deg', '–': '-', '—': '-', '×': 'x',
    };
    return s
        .split('')
        .map((c) => map[c] ?? (c.codeUnitAt(0) < 128 ? c : '?'))
        .join();
  }

  String build() {
    final head = StringBuffer()
      ..writeln('0\nSECTION\n2\nHEADER')
      ..writeln('9\n\$ACADVER\n1\nAC1009')
      ..writeln('0\nENDSEC')
      ..writeln('0\nSECTION\n2\nTABLES')
      ..writeln('0\nTABLE\n2\nLAYER\n70\n${layers.length}');
    var color = 1;
    for (final layer in layers) {
      head.writeln('0\nLAYER\n2\n$layer\n70\n0\n62\n${color++}\n6\nCONTINUOUS');
    }
    head
      ..writeln('0\nENDTAB\n0\nENDSEC')
      ..writeln('0\nSECTION\n2\nENTITIES');
    return '$head$_out'
        '0\nENDSEC\n0\nEOF\n';
  }
}

/// Exporta la planta y sus alzados a formatos de oficina técnica y de
/// iluminación: DXF para CAD y MVR para consolas y programas de
/// previsualización (Vectorworks Spotlight, grandMA3, Capture,
/// WYSIWYG…).
class PlanCadExport {
  PlanCadExport._();

  static const layerWalls = 'MUROS';
  static const layerOpenings = 'HUECOS';
  static const layerLights = 'LUCES';
  static const layerBeams = 'HACES';
  static const layerCameras = 'CAMARAS';
  static const layerPeople = 'ACTORES';
  static const layerProps = 'ATREZZO';
  static const layerText = 'TEXTO';

  /// La planta en DXF, en metros, con el norte hacia arriba.
  static String planDxf(List<PlanElement> elements, double metersPerUnit) {
    final dxf = _Dxf({
      layerWalls,
      layerOpenings,
      layerLights,
      layerBeams,
      layerCameras,
      layerPeople,
      layerProps,
      layerText,
    });
    // El lienzo crece hacia abajo; el CAD, hacia arriba.
    Offset m(Offset p) => Offset(p.dx * metersPerUnit, -p.dy * metersPerUnit);
    Offset dir(Offset d) => Offset(d.dx, -d.dy);
    final units = lightUnitNumbers(elements);

    for (final el in elements) {
      if (PlanSegment.isSegment(el)) {
        final layer = PlanSegment.kind(el) == PlanSegment.kindWall
            ? layerWalls
            : layerProps;
        dxf.line(layer, m(el.position), m(PlanSegment.end(el)));
        continue;
      }
      if (PlanOpening.isOpening(el)) {
        final (a, b) = PlanOpening.span(el);
        dxf.line(layerOpenings, m(a), m(b));
        for (final (from, to) in PlanOpening.leaves(el)) {
          dxf.line(layerOpenings, m(from), m(to));
        }
        continue;
      }
      final at = m(el.position);
      switch (el.type) {
        case ElementType.light:
          final beam = LightBeam.of(el);
          final light = PlanLight.of(el);
          dxf.circle(layerLights, at, 0.15);
          if (beam != null && light != null) {
            final aim = dir(LightScene.aimOf(el));
            final reach = light.source.distanceFor(20).clamp(0.5, 8.0);
            if (beam.spread < 359) {
              final half = beam.spread / 2 * math.pi / 180;
              Offset rot(Offset v, double a) => Offset(
                v.dx * math.cos(a) - v.dy * math.sin(a),
                v.dx * math.sin(a) + v.dy * math.cos(a),
              );
              dxf.line(layerBeams, at, at + rot(aim, half) * reach);
              dxf.line(layerBeams, at, at + rot(aim, -half) * reach);
              dxf.line(layerBeams, at, at + aim * reach);
            } else {
              dxf.circle(layerBeams, at, 0.6);
            }
            final unit = units[el];
            dxf.text(
              layerText,
              at + const Offset(0.25, -0.1),
              [
                if (unit != null) 'U$unit',
                (el.props['name'] as String?) ?? el.displayLabel,
                formatWatts(light.watts),
                '${beam.cct.round()}K',
              ].join(' · '),
            );
          }
        case ElementType.camera:
          final aim = dir(LightScene.aimOf(el));
          final side = Offset(-aim.dy, aim.dx);
          dxf.polyline(layerCameras, [
            at + aim * 0.3,
            at - aim * 0.2 + side * 0.18,
            at - aim * 0.2 - side * 0.18,
          ], closed: true);
          dxf.text(layerText, at + const Offset(0.3, 0.2), el.cameraLabel);
        case ElementType.actor:
          dxf.circle(layerPeople, at, 0.25);
          dxf.text(layerText, at + const Offset(0.3, 0), el.displayLabel);
        case ElementType.prop:
          if (PlanTerrainPainter.isTerrain(el) ||
              el.propType == PropType.meter) {
            continue;
          }
          final r = LightScene.propSizeM(el);
          dxf.polyline(layerProps, [
            at + Offset(-r, -r),
            at + Offset(r, -r),
            at + Offset(r, r),
            at + Offset(-r, r),
          ], closed: true);
          dxf.text(layerText, at + Offset(r + 0.1, 0), el.displayLabel);
        case ElementType.wall:
          break;
      }
    }
    return dxf.build();
  }

  /// Un alzado o un perfil en DXF: lo ancho en X, la altura en Y.
  static String elevationDxf(PlanElevation elevation) {
    final dxf = _Dxf({
      layerWalls,
      layerOpenings,
      layerLights,
      layerBeams,
      layerCameras,
      layerPeople,
      layerProps,
      layerText,
    });
    dxf.line(
      layerWalls,
      Offset(elevation.left - 0.5, 0),
      Offset(elevation.right + 0.5, 0),
    );
    for (final item in elevation.items) {
      List<Offset> box() => [
        Offset(item.from, item.bottom),
        Offset(item.to, item.bottom),
        Offset(item.to, item.top),
        Offset(item.from, item.top),
      ];
      final centre = Offset(item.centre, (item.bottom + item.top) / 2);
      switch (item.kind) {
        case ElevationKind.wall:
          dxf.polyline(layerWalls, box(), closed: true);
        case ElevationKind.opening:
          dxf.polyline(layerOpenings, box(), closed: true);
        case ElevationKind.light:
          dxf.circle(layerLights, centre, 0.13);
          final aim = item.aim;
          if (aim != null && item.beamDeg < 359) {
            final half = item.beamDeg / 2 * math.pi / 180;
            for (final a in [aim - half, aim + half]) {
              dxf.line(
                layerBeams,
                centre,
                centre + Offset(math.cos(a), math.sin(a)) * item.reachM,
              );
            }
          }
          if (!PlanLight.isOverhead(item.element)) {
            dxf.line(layerLights, centre, Offset(item.centre, 0));
          }
          dxf.text(layerText, centre + const Offset(0.2, 0.1), item.label);
        case ElevationKind.actor:
          dxf.circle(layerPeople, Offset(item.centre, item.top - 0.12), 0.12);
          dxf.line(
            layerPeople,
            Offset(item.centre, item.top - 0.24),
            Offset(item.centre, 0.9),
          );
          dxf.line(
            layerPeople,
            Offset(item.centre, 0.9),
            Offset(item.centre - 0.18, 0),
          );
          dxf.line(
            layerPeople,
            Offset(item.centre, 0.9),
            Offset(item.centre + 0.18, 0),
          );
          dxf.text(
            layerText,
            Offset(item.centre - 0.2, item.top + 0.1),
            item.label,
          );
        case ElevationKind.camera:
          dxf.polyline(layerCameras, box(), closed: true);
          dxf.line(
            layerCameras,
            Offset(item.centre, item.bottom),
            Offset(item.centre, 0),
          );
          dxf.text(layerText, Offset(item.to + 0.1, item.top), item.label);
        case ElevationKind.prop:
          dxf.polyline(layerProps, box(), closed: true);
      }
    }
    return dxf.build();
  }

  /// Un identificador estable para cada pieza de la planta, con forma de
  /// UUID, como pide MVR.
  static String _uuid(String seed) {
    int fnv(Iterable<int> bytes, int basis) {
      var h = basis;
      for (final c in bytes) {
        h = ((h ^ c) * 0x01000193) & 0xffffffff;
      }
      return h;
    }

    final bytes = utf8.encode(seed);
    final hex = [
      fnv(bytes, 0x811c9dc5),
      fnv(bytes.reversed, 0x811c9dc5),
      fnv(bytes, 0x050c5d1f),
      fnv(bytes.reversed, 0x050c5d1f),
    ].map((v) => v.toRadixString(16).padLeft(8, '0')).join().toUpperCase();
    // Versión 4 y variante RFC 4122, para que lo acepte cualquier lector.
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '4${hex.substring(13, 16)}-'
        '${'89AB'[int.parse(hex[16], radix: 16) % 4]}${hex.substring(17, 20)}-'
        '${hex.substring(20, 32)}';
  }

  /// La planta en MVR (My Virtual Rig, DIN SPEC 15800): un .zip con
  /// `GeneralSceneDescription.xml`. Lleva cada luz con su posición en
  /// milímetros, su giro, su altura, su unidad y su tipo de aparato
  /// («Marca@Modelo»), para que el programa que lo abra le ponga su GDTF.
  /// Sin GDTF dentro: el programa los busca en su librería.
  static Uint8List planMvr(
    List<PlanElement> elements,
    double metersPerUnit, {
    String layerName = 'IRIS',
  }) {
    final units = lightUnitNumbers(elements);
    String mm(double meters) => (meters * 1000).toStringAsFixed(1);
    final builder = XmlBuilder()
      ..processing('xml', 'version="1.0" encoding="UTF-8" standalone="no"');
    builder.element(
      'GeneralSceneDescription',
      attributes: {'verMajor': '1', 'verMinor': '6', 'provider': 'IRIS'},
      nest: () {
        builder.element('UserData');
        builder.element(
          'Scene',
          nest: () {
            builder.element('AUXData');
            builder.element(
              'Layers',
              nest: () {
                builder.element(
                  'Layer',
                  attributes: {
                    'name': layerName,
                    'uuid': _uuid('layer:$layerName'),
                  },
                  nest: () {
                    builder.element(
                      'ChildList',
                      nest: () {
                        for (final MapEntry(key: el, value: unit)
                            in units.entries) {
                          final light = PlanLight.of(el);
                          final beam = LightBeam.of(el);
                          if (light == null || beam == null) continue;
                          final name =
                              (el.props['name'] as String?) ?? el.displayLabel;
                          final x = el.position.dx * metersPerUnit;
                          final y = -el.position.dy * metersPerUnit;
                          final z = PlanLight.isOverhead(el)
                              ? PlanLight.heightOf(el)
                              : (el.props[PlanLight.heightKey] as num?)
                                        ?.toDouble() ??
                                    PlanElevation.standM;
                          // Giro alrededor de Z: el norte de la planta es
                          // el eje Y del MVR.
                          final a = -el.rotation * math.pi / 180;
                          final c = math.cos(a), s = math.sin(a);
                          String v(double n) => n.toStringAsFixed(6);
                          builder.element(
                            'Fixture',
                            attributes: {
                              'name': name,
                              'uuid': _uuid('fixture:${el.id}:$unit:$name'),
                            },
                            nest: () {
                              builder.element(
                                'Matrix',
                                nest:
                                    '{${v(c)},${v(s)},0}{${v(-s)},${v(c)},0}'
                                    '{0,0,1}{${mm(x)},${mm(y)},${mm(z)}}',
                              );
                              builder.element(
                                'GDTFSpec',
                                nest: '${name.replaceFirst(' ', '@')}.gdtf',
                              );
                              builder.element('GDTFMode', nest: 'Default');
                              builder.element('FixtureID', nest: '$unit');
                              builder.element('UnitNumber', nest: '$unit');
                              builder.element('Color', nest: _cie(beam.cct));
                            },
                          );
                        }
                      },
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
    final xml = builder.buildDocument().toXmlString(pretty: true);
    final archive = Archive()
      ..addFile(
        ArchiveFile(
          'GeneralSceneDescription.xml',
          utf8.encode(xml).length,
          utf8.encode(xml),
        ),
      );
    return Uint8List.fromList(ZipEncoder().encode(archive)!);
  }

  /// Color de la luz en CIE xyY, como lo pide MVR («x,y,Y»).
  static String _cie(double kelvin) {
    // Kim et al.: el punto del cuerpo negro para 1667–25 000 K.
    final t = kelvin.clamp(1667, 25000).toDouble();
    final x = t <= 4000
        ? -0.2661239e9 / (t * t * t) -
              0.2343589e6 / (t * t) +
              0.8776956e3 / t +
              0.179910
        : -3.0258469e9 / (t * t * t) +
              2.1070379e6 / (t * t) +
              0.2226347e3 / t +
              0.240390;
    final y = t <= 2222
        ? -1.1063814 * x * x * x -
              1.34811020 * x * x +
              2.18555832 * x -
              0.20219683
        : t <= 4000
        ? -0.9549476 * x * x * x -
              1.37418593 * x * x +
              2.09137015 * x -
              0.16748867
        : 3.0817580 * x * x * x -
              5.87338670 * x * x +
              3.75112997 * x -
              0.37001483;
    return '${x.toStringAsFixed(6)},${y.toStringAsFixed(6)},100.000000';
  }
}
