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

  test('un HTML copiado de Google Docs: enlaces con &amp; e imágenes '
      'incrustadas', () {
    const html =
        '<meta charset="utf-8"><b id="docs-internal-guid-1">'
        '<img src="https://lh7-rt.googleusercontent.com/docsz/AD_4nX?key=abc&amp;w=600" '
        'width="602" height="339" /></b>'
        '<img src="data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJ'
        'AAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==">';
    final images = ClipboardImageReader.imagesInHtml(html);
    expect(images, hasLength(2));
    expect(
      images.first.url.toString(),
      'https://lh7-rt.googleusercontent.com/docsz/AD_4nX?key=abc&w=600',
    );
    expect(images.last.inline, isNotNull);
    expect(images.last.inline!.extension, '.png');
    expect(images.last.inline!.bytes.take(4), [0x89, 0x50, 0x4E, 0x47]);
  });
}
