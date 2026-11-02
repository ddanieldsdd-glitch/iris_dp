import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:iris_dp/features/camera_plan/rig/scan_glb.dart';

/// Un GLB mínimo con un triángulo de pie en Z (como lo da RealityScan).
Uint8List tinyGlb(List<double> xyz) {
  final bin = Float32List.fromList(xyz).buffer.asUint8List();
  final json = utf8.encode(
    jsonEncode({
      'asset': {'version': '2.0'},
      'buffers': [
        {'byteLength': bin.length},
      ],
      'bufferViews': [
        {'buffer': 0, 'byteLength': bin.length},
      ],
      'accessors': [
        {
          'bufferView': 0,
          'componentType': 5126,
          'type': 'VEC3',
          'count': xyz.length ~/ 3,
          'min': [0, 0, 0],
          'max': [1, 1, 1],
        },
      ],
      'meshes': [
        {
          'primitives': [
            {
              'attributes': {'POSITION': 0},
            },
          ],
        },
      ],
    }),
  );
  final jl = (json.length + 3) & ~3;
  final out = Uint8List(20 + jl + 8 + bin.length);
  final w = ByteData.sublistView(out);
  w.setUint32(0, 0x46546C67, Endian.little);
  w.setUint32(4, 2, Endian.little);
  w.setUint32(8, out.length, Endian.little);
  w.setUint32(12, jl, Endian.little);
  w.setUint32(16, 0x4E4F534A, Endian.little);
  out.setRange(20, 20 + json.length, json);
  out.fillRange(20 + json.length, 20 + jl, 0x20);
  w.setUint32(20 + jl, bin.length, Endian.little);
  w.setUint32(24 + jl, 0x004E4942, Endian.little);
  out.setRange(28 + jl, out.length, bin);
  return out;
}

(Map, List<double>) read(Uint8List glb) {
  final d = ByteData.sublistView(glb);
  final jl = d.getUint32(12, Endian.little);
  final json = jsonDecode(utf8.decode(glb.sublist(20, 20 + jl))) as Map;
  final count = (json['accessors'][0]['count'] as int) * 3;
  final floats = [
    for (var i = 0; i < count; i++)
      d.getFloat32(28 + jl + i * 4, Endian.little).toDouble(),
  ];
  return (json, floats);
}

void main() {
  test('de Z arriba a Y arriba: (x, y, z) pasa a (x, z, -y)', () {
    final fixed = glbZUpToYUp(tinyGlb([1, 2, 3, 4, 5, 6, 0, 0, 2.5]))!;
    final (json, v) = read(fixed);
    expect(v, [1, 3, -2, 4, 6, -5, 0, 2.5, -0]);
    expect(json['accessors'][0]['min'], [0, 2.5, -5]);
    expect(json['accessors'][0]['max'], [4, 6, 0]);
    expect(
      ByteData.sublistView(fixed).getUint32(8, Endian.little),
      fixed.length,
    );
  });

  test('si no es un GLB, nada', () {
    expect(
      glbZUpToYUp(Uint8List.fromList(utf8.encode('hola mundo, no soy'))),
      isNull,
    );
  });
}
