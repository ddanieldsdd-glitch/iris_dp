import 'dart:convert';
import 'dart:typed_data';

/// Referencia de NSKeyedArchiver dentro de un plist binario.
class PlistUid {
  final int value;

  const PlistUid(this.value);

  @override
  bool operator ==(Object other) => other is PlistUid && other.value == value;

  @override
  int get hashCode => value.hashCode;
}

/// Lector mínimo de plist binario (`bplist00`), lo justo para leer los
/// ajustes de un pincel de Procreate. Si algo no cuadra, lanza
/// [FormatException].
class BinaryPlist {
  BinaryPlist._(this._data);

  final ByteData _data;
  late final int _refSize;
  late final List<int> _offsets;
  final Map<int, Object?> _cache = {};

  static Object? parse(Uint8List bytes) {
    if (bytes.length < 40 ||
        ascii.decode(bytes.sublist(0, 8), allowInvalid: true) != 'bplist00') {
      throw const FormatException('No es un plist binario');
    }
    final reader = BinaryPlist._(ByteData.sublistView(bytes));
    return reader._read();
  }

  Object? _read() {
    final len = _data.lengthInBytes;
    final trailer = len - 32;
    final offsetSize = _data.getUint8(trailer + 6);
    _refSize = _data.getUint8(trailer + 7);
    final count = _uint(trailer + 8, 8);
    final top = _uint(trailer + 16, 8);
    final table = _uint(trailer + 24, 8);
    if (count <= 0 || count > 1 << 20 || table + count * offsetSize > len) {
      throw const FormatException('Tabla de objetos no válida');
    }
    _offsets = [
      for (var i = 0; i < count; i++) _uint(table + i * offsetSize, offsetSize),
    ];
    return _object(top, 0);
  }

  int _uint(int at, int size) {
    var v = 0;
    for (var i = 0; i < size; i++) {
      v = (v << 8) | _data.getUint8(at + i);
    }
    return v;
  }

  /// Longitud de un objeto: la del marcador, o un entero que le sigue.
  (int, int) _length(int at, int low) {
    if (low != 0x0F) return (low, at + 1);
    final marker = _data.getUint8(at + 1);
    final size = 1 << (marker & 0x0F);
    return (_uint(at + 2, size), at + 2 + size);
  }

  Object? _object(int index, int depth) {
    if (depth > 64 || index < 0 || index >= _offsets.length) {
      throw const FormatException('Referencia fuera de rango');
    }
    if (_cache.containsKey(index)) return _cache[index];
    final at = _offsets[index];
    final marker = _data.getUint8(at);
    final type = marker >> 4;
    final low = marker & 0x0F;
    Object? value;
    switch (type) {
      case 0x0:
        value = switch (low) {
          0x08 => false,
          0x09 => true,
          _ => null,
        };
      case 0x1:
        final size = 1 << low;
        value = size == 8 ? _data.getInt64(at + 1) : _uint(at + 1, size);
      case 0x2:
        value = low == 2 ? _data.getFloat32(at + 1) : _data.getFloat64(at + 1);
      case 0x3:
        value = _data.getFloat64(at + 1);
      case 0x4:
        final (n, start) = _length(at, low);
        value = Uint8List.sublistView(_data, start, start + n);
      case 0x5:
        final (n, start) = _length(at, low);
        value = latin1.decode(Uint8List.sublistView(_data, start, start + n));
      case 0x6:
        final (n, start) = _length(at, low);
        final units = [
          for (var i = 0; i < n; i++) _data.getUint16(start + i * 2),
        ];
        value = String.fromCharCodes(units);
      case 0x8:
        value = PlistUid(_uint(at + 1, low + 1));
      case 0xA:
        final (n, start) = _length(at, low);
        value = [
          for (var i = 0; i < n; i++)
            _object(_uint(start + i * _refSize, _refSize), depth + 1),
        ];
      case 0xD:
        final (n, start) = _length(at, low);
        final map = <String, Object?>{};
        for (var i = 0; i < n; i++) {
          final key = _object(_uint(start + i * _refSize, _refSize), depth + 1);
          final val = _object(
            _uint(start + (n + i) * _refSize, _refSize),
            depth + 1,
          );
          map['$key'] = val;
        }
        value = map;
      default:
        value = null;
    }
    _cache[index] = value;
    return value;
  }

  /// Deshace un NSKeyedArchiver: devuelve el objeto raíz con sus
  /// referencias resueltas (hasta [maxDepth] niveles).
  static Object? unarchive(Object? plist, {int maxDepth = 6}) {
    if (plist is! Map || plist[r'$objects'] is! List) return plist;
    final objects = plist[r'$objects'] as List;
    final top = plist[r'$top'];
    Object? root = top is Map ? top['root'] : null;
    Object? resolve(Object? v, int depth) {
      if (depth > maxDepth) return null;
      if (v is PlistUid) {
        if (v.value < 0 || v.value >= objects.length) return null;
        final o = objects[v.value];
        if (o == r'$null') return null;
        return resolve(o, depth + 1);
      }
      if (v is Map) {
        return {
          for (final e in v.entries)
            if (e.key != r'$class') '${e.key}': resolve(e.value, depth + 1),
        };
      }
      if (v is List) return [for (final e in v) resolve(e, depth + 1)];
      return v;
    }

    root ??= objects.length > 1 ? const PlistUid(1) : null;
    return resolve(root, 0);
  }
}
