import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:iris_dp/features/visual_bible/moodboard_palette_extractor.dart';

Uint8List _pngWithColorBands() {
  final image = img.Image(width: 200, height: 40);
  final bands = <img.Color>[
    img.ColorRgb8(20, 40, 80),
    img.ColorRgb8(180, 60, 40),
    img.ColorRgb8(40, 140, 90),
    img.ColorRgb8(220, 180, 60),
    img.ColorRgb8(90, 90, 100),
  ];
  final bandW = image.width ~/ bands.length;
  for (var y = 0; y < image.height; y++) {
    for (var x = 0; x < image.width; x++) {
      final i = (x ~/ bandW).clamp(0, bands.length - 1);
      image.setPixel(x, y, bands[i]);
    }
  }
  return Uint8List.fromList(img.encodePng(image));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('fromBytes extracts a non-empty multi-color palette', () async {
    final bytes = _pngWithColorBands();
    final colors = await MoodboardPaletteExtractor.fromBytes(bytes, count: 5);

    expect(colors, isNotEmpty);
    expect(colors.length, greaterThanOrEqualTo(3));

    final hexes = colors.map(MoodboardPaletteExtractor.toHex).toList();
    for (final h in hexes) {
      expect(h, matches(RegExp(r'^#[0-9A-F]{6}$')));
    }

    final first = colors.first;
    expect(
      colors.every(
        (c) =>
            (c.r - first.r).abs() < 0.02 &&
            (c.g - first.g).abs() < 0.02 &&
            (c.b - first.b).abs() < 0.02,
      ),
      isFalse,
    );
  });

  test('toHex / fromHex round-trip', () {
    const c = Color(0xFF1A3C40);
    final hex = MoodboardPaletteExtractor.toHex(c);
    final back = MoodboardPaletteExtractor.fromHex(hex);
    expect(back, isNotNull);
    expect((back!.r - c.r).abs(), lessThan(0.01));
  });

  test('fromBytes empty returns empty', () async {
    final colors = await MoodboardPaletteExtractor.fromBytes(Uint8List(0));
    expect(colors, isEmpty);
  });
}
