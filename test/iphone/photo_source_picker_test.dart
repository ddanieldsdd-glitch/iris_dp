import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:iris_dp/core/theme/app_theme.dart';
import 'package:iris_dp/core/utils/photo_source_picker.dart';

/// IC.1: «Añadir desde: Cámara · Fototeca · Archivos» (docs/PLAN_IPHONE_CAPTURA.md).
const _iphone = Size(390, 844);
const _iphoneSe = Size(375, 667);
const _ipad = Size(1024, 768);

Future<void> _pumpButton(WidgetTester tester, Size size) async {
  tester.view.devicePixelRatio = 3;
  tester.view.physicalSize = size * 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.dark,
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: TextButton(
              onPressed: () => PhotoSourcePicker.pickImages(
                context,
                title: 'Galería · Bosque',
              ),
              child: const Text('Añadir'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Añadir'));
  await tester.pumpAndSettle();
}

void main() {
  final calls = <(PhotoSource, bool)>[];

  setUp(() {
    calls.clear();
    PhotoSourcePicker.debugPickOverride = (source, multiple) async {
      calls.add((source, multiple));
      return ['/tmp/${source.name}.jpg'];
    };
  });
  tearDown(() => PhotoSourcePicker.debugPickOverride = null);

  for (final (name, size) in [
    ('iPhone 390', _iphone),
    ('iPhone SE 375', _iphoneSe),
    ('iPad', _ipad),
  ]) {
    testWidgets('$name: la hoja ofrece las tres fuentes sin desbordes', (
      tester,
    ) async {
      await _pumpButton(tester, size);
      expect(find.text('Galería · Bosque'), findsOneWidget);
      expect(find.text('Cámara'), findsOneWidget);
      expect(find.text('Fototeca'), findsOneWidget);
      expect(find.text('Archivos'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Fototeca devuelve varias; Cámara, la foto hecha', (
    tester,
  ) async {
    await _pumpButton(tester, _iphone);
    await tester.tap(find.text('Fototeca'));
    await tester.pumpAndSettle();
    expect(calls.single, (PhotoSource.library, true));

    await tester.tap(find.text('Añadir'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cámara'));
    await tester.pumpAndSettle();
    expect(calls.last.$1, PhotoSource.camera);
  });

  testWidgets('Cerrar la hoja no elige nada', (tester) async {
    await _pumpButton(tester, _iphone);
    await tester.tapAt(const Offset(195, 40));
    await tester.pumpAndSettle();
    expect(calls, isEmpty);
    expect(find.text('Cámara'), findsNothing);
  });
}
