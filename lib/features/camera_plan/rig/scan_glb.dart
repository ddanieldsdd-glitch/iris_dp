import 'dart:convert';
import 'dart:typed_data';

/// RealityScan exporta el GLB con Z hacia arriba, y glTF (el visor de IRIS
/// y el importador de Unreal) espera Y hacia arriba: sin esto, el escaneo
/// sale tumbado. Gira los vértices (y las normales) -90° sobre X, de
/// (x, y, z) a (x, z, -y), y rehace los mínimos y máximos. Devuelve el GLB
/// nuevo, o `null` si no es un GLB que se entienda.
Uint8List? glbZUpToYUp(Uint8List glb) {
  if (glb.length < 20) return null;
  final head = ByteData.sublistView(glb);
  if (head.getUint32(0, Endian.little) != 0x46546C67) return null; // glTF
  final jsonLen = head.getUint32(12, Endian.little);
  if (head.getUint32(16, Endian.little) != 0x4E4F534A) return null; // JSON
  final Map json;
  try {
    json = jsonDecode(utf8.decode(glb.sublist(20, 20 + jsonLen))) as Map;
  } catch (_) {
    return null;
  }
  final binChunk = 20 + jsonLen;
  if (binChunk + 8 > glb.length) return null;
  final binStart = binChunk + 8;
  final out = Uint8List.fromList(glb);
  final data = ByteData.sublistView(out);
  final accessors = (json['accessors'] as List? ?? const []).cast<Map>();
  final views = (json['bufferViews'] as List? ?? const []).cast<Map>();
  final done = <int>{};
  for (final mesh in (json['meshes'] as List? ?? const []).cast<Map>()) {
    for (final prim in (mesh['primitives'] as List? ?? const []).cast<Map>()) {
      final attrs = (prim['attributes'] as Map?) ?? const {};
      for (final name in ['POSITION', 'NORMAL']) {
        final index = attrs[name];
        if (index is! int || !done.add(index)) continue;
        final acc = accessors[index];
        // Solo float (5126) y VEC3, sin compartir vista con otro dato.
        if (acc['componentType'] != 5126 || acc['type'] != 'VEC3') continue;
        final view = views[acc['bufferView'] as int];
        final stride = (view['byteStride'] as int?) ?? 12;
        final base =
            binStart +
            ((view['byteOffset'] as int?) ?? 0) +
            ((acc['byteOffset'] as int?) ?? 0);
        final count = acc['count'] as int;
        final lo = [double.infinity, double.infinity, double.infinity];
        final hi = [-double.infinity, -double.infinity, -double.infinity];
        for (var i = 0; i < count; i++) {
          final at = base + i * stride;
          final y = data.getFloat32(at + 4, Endian.little);
          final z = data.getFloat32(at + 8, Endian.little);
          data.setFloat32(at + 4, z, Endian.little);
          data.setFloat32(at + 8, -y, Endian.little);
          final v = [data.getFloat32(at, Endian.little), z, -y];
          for (var k = 0; k < 3; k++) {
            if (v[k] < lo[k]) lo[k] = v[k];
            if (v[k] > hi[k]) hi[k] = v[k];
          }
        }
        if (acc.containsKey('min') || acc.containsKey('max')) {
          acc['min'] = lo;
          acc['max'] = hi;
        }
      }
    }
  }
  // El JSON cambia de largo: se rellena con espacios hasta múltiplo de 4.
  final text = utf8.encode(jsonEncode(json));
  final padded = (text.length + 3) & ~3;
  final bin = out.sublist(binChunk);
  final result = Uint8List(12 + 8 + padded + bin.length);
  final w = ByteData.sublistView(result);
  w.setUint32(0, 0x46546C67, Endian.little);
  w.setUint32(4, 2, Endian.little);
  w.setUint32(8, result.length, Endian.little);
  w.setUint32(12, padded, Endian.little);
  w.setUint32(16, 0x4E4F534A, Endian.little);
  result.setRange(20, 20 + text.length, text);
  result.fillRange(20 + text.length, 20 + padded, 0x20);
  result.setRange(20 + padded, result.length, bin);
  return result;
}
