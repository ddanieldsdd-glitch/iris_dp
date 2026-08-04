import 'package:flutter_test/flutter_test.dart';
import 'package:iris_dp/core/utils/clipboard_image_reader.dart';

void main() {
  group('ClipboardImageReader.extractHttpUrl', () {
    test('parsea URL directa', () {
      expect(
        ClipboardImageReader.extractHttpUrl('https://example.com/photo.jpg'),
        Uri.parse('https://example.com/photo.jpg'),
      );
    });

    test('extrae URL embebida en texto', () {
      expect(
        ClipboardImageReader.extractHttpUrl('Mira esto: https://cdn.site/img.png '),
        Uri.parse('https://cdn.site/img.png'),
      );
    });

    test('devuelve null para texto sin URL', () {
      expect(ClipboardImageReader.extractHttpUrl('solo texto'), isNull);
    });
  });

  group('ClipboardImageReader.extractImageUrlFromHtml', () {
    test('extrae src de img', () {
      expect(
        ClipboardImageReader.extractImageUrlFromHtml(
          '<img src="https://cdn.shotdeck.com/shot/abc.jpg" alt="frame">',
        ),
        Uri.parse('https://cdn.shotdeck.com/shot/abc.jpg'),
      );
    });

    test('extrae URL protocol-relative', () {
      expect(
        ClipboardImageReader.extractImageUrlFromHtml(
          '<img src="//cdn.shotdeck.com/shot/abc.jpg">',
        ),
        Uri.parse('https://cdn.shotdeck.com/shot/abc.jpg'),
      );
    });
  });
}
