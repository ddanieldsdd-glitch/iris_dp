import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iris_dp/core/settings/app_prefs.dart';
import 'package:iris_dp/core/theme/app_theme.dart';
import 'package:iris_dp/features/unreal_link/unreal_link.dart';
import 'package:iris_dp/features/unreal_link/unreal_tutorial_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  for (final size in const [Size(1280, 800), Size(820, 1180)]) {
    testWidgets('el tutorial se recorre entero a $size', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await AppPrefs.reloadForTest();
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: UnrealTutorialScreen(link: UnrealLink()),
        ),
      );
      await tester.pump();

      final titles = <String>[];
      for (var i = 0; i < 7; i++) {
        expect(find.textContaining('Paso ${i + 1} de 7'), findsOneWidget);
        titles.add(
          (tester.widget<Text>(find.byType(Text).at(1))).data ?? '',
        );
        await tester.tap(find.text(i == 6 ? 'Terminar' : 'Siguiente'));
        await tester.pump();
      }
      expect(titles, [
        'IRIS y Unreal',
        'Preparar el proyecto',
        'Abrir Unreal',
        'Conectar',
        'Render RTX',
        'Cómo se trabaja',
        'Si algo falla',
      ]);
    });
  }
}
