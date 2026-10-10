import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iris_dp/core/catalog/equipment_facts.dart';
import 'package:iris_dp/core/theme/app_theme.dart';
import 'package:iris_dp/features/visual_bible/widgets/camera_modes_widgets.dart';
import 'package:iris_dp/shared/visual_bible/bible_table.dart';

const _cam = CameraFacts(
  name: 'ARRI ALEXA 35',
  modes: [
    CameraModeFacts(
      name: '4.6K Open Gate',
      widthPx: 4608,
      heightPx: 3164,
      cropFactor: 1,
      codec: 'ARRIRAW',
      fpsMax: 75,
    ),
    CameraModeFacts(
      name: '2K S16',
      widthPx: 2048,
      heightPx: 1152,
      cropFactor: 0.44,
      codec: 'ProRes',
      fpsMax: 120,
    ),
    CameraModeFacts(name: '3K', widthPx: 3072, heightPx: 3072),
  ],
);

Widget _host(Widget child) => MaterialApp(
  theme: AppTheme.dark,
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

void main() {
  testWidgets('avisa del recorte del modo y de la cadencia que no cabe', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    // Modo completo a 24: sin avisos.
    await tester.pumpWidget(
      _host(
        CameraModePicker(
          facts: _cam,
          selected: '4.6K Open Gate',
          wantedFps: const ['24', ''],
          onSelected: (_) {},
        ),
      ),
    );
    expect(find.textContaining('recorta'), findsNothing);
    expect(find.textContaining('hay que pasar'), findsNothing);

    // A 100 fps ese modo no llega: dice a cuál pasar y que recorta.
    await tester.pumpWidget(
      _host(
        CameraModePicker(
          facts: _cam,
          selected: '4.6K Open Gate',
          wantedFps: const ['24', '100 fps'],
          onSelected: (_) {},
        ),
      ),
    );
    expect(
      find.textContaining('Para 100 fps hay que pasar a 2K S16'),
      findsOneWidget,
    );
    expect(find.textContaining('recorta el sensor al 44 %'), findsOneWidget);

    // El modo recortado avisa de lo que supone para la focal.
    await tester.pumpWidget(
      _host(
        CameraModePicker(
          facts: _cam,
          selected: '2K S16',
          onSelected: (_) {},
        ),
      ),
    );
    expect(find.textContaining('44 % del ancho del sensor'), findsOneWidget);
    expect(find.textContaining('encuadra como un 80 mm'), findsOneWidget);

    // Un modo sin datos en el catálogo lo dice.
    await tester.pumpWidget(
      _host(CameraModePicker(facts: _cam, selected: '3K', onSelected: (_) {})),
    );
    expect(find.textContaining('Sin dato en el catálogo'), findsOneWidget);

    // Sin cámara, lo pide.
    await tester.pumpWidget(
      _host(CameraModePicker(facts: null, selected: '', onSelected: (_) {})),
    );
    expect(find.textContaining('Elige una cámara'), findsOneWidget);
  });

  testWidgets('la matriz lista los modos y guarda solo los marcados', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    var value = const BibleTableValue();
    late StateSetter rebuild;
    await tester.pumpWidget(
      _host(
        StatefulBuilder(
          builder: (context, setState) {
            rebuild = setState;
            return CameraRecordingMatrix(
              facts: _cam,
              value: value,
              onChanged: (next) => rebuild(() => value = next),
            );
          },
        ),
      ),
    );
    expect(find.text('4.6K Open Gate'), findsOneWidget);
    expect(find.text('2K S16'), findsOneWidget);
    expect(value.rows, isEmpty);

    await tester.tap(find.byType(Checkbox).at(1));
    await tester.pump();
    expect(value.rows.single.first, '2K S16');
    expect(value.rows.single[3], '44 %');
    expect(value.rows.single[5], '120 fps');

    await tester.enterText(find.byType(TextFormField), 'Cámara lenta');
    await tester.pump();
    expect(value.rows.single.last, 'Cámara lenta');

    await tester.tap(find.byType(Checkbox).at(1));
    await tester.pump();
    expect(value.rows, isEmpty);
    expect(tester.takeException(), isNull);
  });
}
