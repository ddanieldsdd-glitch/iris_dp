import 'package:flutter_test/flutter_test.dart';
import 'package:iris_dp/core/catalog/equipment_facts.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('ALEXA 35 del catálogo: ficha, modos, códec, fps y recorte', () async {
    final cam = (await EquipmentCatalog.camera(externalId: 'arri_alexa35'))!;
    expect(cam.name, 'ARRI ALEXA 35');
    expect(cam.bodyFacts['Montura'], 'LPL');
    expect(cam.bodyFacts['ISO nativo'], '800');
    expect(cam.bodyFacts['Curva log'], 'LogC4');
    expect(cam.bodyFacts['Peso del cuerpo'], '2.90 kg');
    expect(cam.modes.length, greaterThan(5));

    final open = cam.mode('4.6K 3:2 Open Gate')!;
    expect(open.resolution, '4608 × 3164');
    expect(open.codec, 'ARRIRAW/ProRes');
    expect(open.fpsLabel, '120 fps');
    expect(open.crops, isFalse);
    expect(open.cropWarning(), isNull);

    // 4K usa menos sensor: se avisa, con lo que supone para una focal.
    final fourK = cam.mode('4k 16:9')!;
    expect(fourK.crops, isTrue);
    expect(fourK.cropWarning(), contains('89 %'));
    expect(fourK.cropWarning(), contains('encuadra como un 39 mm'));

    // A 110 fps no llegan todos los modos.
    final fast = cam.modesReaching(110);
    expect(fast, isNotEmpty);
    expect(fast.every((m) => m.fpsMax! >= 110), isTrue);
    expect(fast.any((m) => m.name == '3K 1:1'), isFalse);
    // Primero el que más sensor usa.
    expect(fast.first.cropFactor, 1.0);
  });

  test('una cámara duplicada sin identificador se encuentra por nombre',
      () async {
    final cam = await EquipmentCatalog.camera(brand: 'ARRI', model: 'ALEXA 35');
    expect(cam?.bodyFacts['Montura'], 'LPL');
    expect(await EquipmentCatalog.camera(brand: 'Marca', model: 'Rara'), isNull);
  });

  test('lo que falta en la base lo pone el catálogo, modo a modo', () {
    const fromDb = CameraFacts(
      name: 'X',
      mount: 'PL',
      modes: [CameraModeFacts(name: '4K', widthPx: 4096, heightPx: 2160)],
    );
    const fromCatalog = CameraFacts(
      name: 'X',
      mount: 'LPL',
      weightKg: 3,
      modes: [
        CameraModeFacts(name: '4k', codec: 'RAW', fpsMax: 60),
        CameraModeFacts(name: '2K', fpsMax: 120),
      ],
    );
    final merged = fromDb.mergedWith(fromCatalog);
    expect(merged.mount, 'PL');
    expect(merged.weightKg, 3);
    expect(merged.modes.map((m) => m.name), ['4K', '2K']);
    expect(merged.modes.first.codec, 'RAW');
    expect(merged.modes.first.resolution, '4096 × 2160');
  });

  test('peso de lentes y números sueltos', () async {
    expect(await EquipmentCatalog.lensWeightKg('arri_signature_12'), 2.8);
    expect(await EquipmentCatalog.lensWeightKg('no_existe'), isNull);
    expect(firstNumber('48 fps'), 48);
    expect(firstNumber('23,976'), closeTo(23.976, 1e-9));
    expect(firstNumber('alta'), isNull);
  });
}
