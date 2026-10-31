import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:iris_dp/core/utils/pdf_safe_image.dart';

void main() {
  late Directory dir;
  late String bigPath;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('iris_pdf_image');
    bigPath = '${dir.path}/grande.png';
    File(
      bigPath,
    ).writeAsBytesSync(img.encodePng(img.Image(width: 3000, height: 1000)));
  });

  tearDown(() => dir.deleteSync(recursive: true));

  testWidgets('reduce el lado mayor y conserva la proporción', (tester) async {
    final bytes = await tester.runAsync(
      () => PdfSafeImage.loadFromPathMaxEdge(bigPath),
    );
    // Sin transparencia sale en JPEG, que pesa menos y el PDF mete tal cual.
    expect(bytes![0], 0xFF);
    final decoded = img.decodeImage(bytes)!;
    expect(decoded.width, 2048);
    expect(decoded.height, 683);
  });

  testWidgets('con transparencia sigue en PNG', (tester) async {
    final path = '${dir.path}/recorte.png';
    final image = img.Image(width: 3000, height: 1000, numChannels: 4);
    File(path).writeAsBytesSync(img.encodePng(image));
    final bytes = await tester.runAsync(
      () => PdfSafeImage.loadFromPathMaxEdge(path),
    );
    expect(img.decodePng(bytes!)!.width, 2048);
  });

  testWidgets('dentro de una exportación la misma imagen se carga una vez', (
    tester,
  ) async {
    final loads = await tester.runAsync(
      () => PdfSafeImage.withExportCache(
        () async => <Uint8List?>[
          await PdfSafeImage.loadFromPathMaxEdge(bigPath),
          await PdfSafeImage.loadFromPathMaxEdge(bigPath),
        ],
      ),
    );
    expect(identical(loads![0], loads[1]), isTrue);

    // Fuera de una exportación no hay caché.
    final again = await tester.runAsync(
      () => PdfSafeImage.loadFromPathMaxEdge(bigPath),
    );
    expect(identical(again, loads[0]), isFalse);
  });
}
