import 'dart:io';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Huella visual de una imagen (dHash de 64 bits): la misma foto, aunque
/// esté recomprimida o a otro tamaño (la de un Word frente al original), da
/// casi la misma huella. Nula si no se puede leer.
String? visualFingerprint(Uint8List bytes) {
  final img.Image? decoded;
  try {
    decoded = img.decodeImage(bytes);
  } catch (_) {
    // Lo que no es una imagen (o viene roto) no tiene huella.
    return null;
  }
  if (decoded == null) return null;
  final small = img.copyResize(
    img.grayscale(decoded),
    width: 9,
    height: 8,
    interpolation: img.Interpolation.average,
  );
  var bits = BigInt.zero;
  for (var y = 0; y < 8; y++) {
    for (var x = 0; x < 8; x++) {
      final left = small.getPixel(x, y).luminance;
      final right = small.getPixel(x + 1, y).luminance;
      bits = (bits << 1) | (left > right ? BigInt.one : BigInt.zero);
    }
  }
  return bits.toRadixString(16).padLeft(16, '0');
}

/// [visualFingerprint] de un archivo; nula si no existe o no se lee.
String? visualFingerprintOfFile(String path) {
  final file = File(path);
  if (!file.existsSync()) return null;
  try {
    return visualFingerprint(file.readAsBytesSync());
  } catch (_) {
    return null;
  }
}

/// Bits distintos entre dos huellas visuales.
int fingerprintDistance(String a, String b) {
  final x = BigInt.parse(a, radix: 16) ^ BigInt.parse(b, radix: 16);
  var count = 0;
  for (var v = x; v > BigInt.zero; v >>= 1) {
    if (v & BigInt.one == BigInt.one) count++;
  }
  return count;
}

/// ¿Es la misma imagen a la vista? Hasta [tolerance] bits de 64 distintos.
bool sameImage(String a, String b, {int tolerance = 10}) =>
    fingerprintDistance(a, b) <= tolerance;
