import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iris_dp/core/settings/app_prefs.dart';
import 'package:iris_dp/core/settings/settings_center_screen.dart';
import 'package:iris_dp/core/settings/settings_section.dart';
import 'package:iris_dp/core/theme/app_theme.dart';
import 'package:iris_dp/features/settings/sections/storyboard_settings_section.dart';
import 'package:iris_dp/features/storyboard/storyboard_prefs.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AppPrefs.reloadForTest();
  });

  final sections = [
    SettingsSectionSpec(
      id: 'about',
      title: 'Acerca de',
      icon: Icons.info_outline,
      color: Colors.grey,
      group: SettingsGroup.app,
      builder: (_, _) => const Text('IRIS'),
    ),
    SettingsSectionSpec(
      id: 'storyboard',
      title: 'Storyboard',
      icon: Icons.view_comfy_outlined,
      color: Colors.blue,
      group: SettingsGroup.screens,
      prefKeys: StoryboardPrefs.all,
      builder: (_, scope) => StoryboardSettingsSection(scope: scope),
    ),
  ];

  Future<void> pump(WidgetTester tester, {int? projectId}) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.dark,
          home: SettingsCenterScreen(
            sections: sections,
            initialSectionId: 'storyboard',
            projectId: projectId,
            projectName: projectId == null ? null : 'El Bosque de Aldrun',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('sin proyecto no hay selector de alcance', (tester) async {
    await pump(tester);
    expect(find.text('Este proyecto'), findsNothing);
    expect(find.text('APP'), findsOneWidget);
    expect(find.text('PANTALLAS'), findsOneWidget);

    await tester.tap(find.text('Rejilla'));
    await tester.pumpAndSettle();
    expect(AppPrefs.instance.get(StoryboardPrefs.layout), 'grid');
  });

  testWidgets('desde un proyecto, el cambio queda solo en él', (
    tester,
  ) async {
    await pump(tester, projectId: 3);
    expect(find.text('Este proyecto'), findsOneWidget);
    expect(find.text('El Bosque de Aldrun'), findsOneWidget);

    await tester.tap(find.text('Lista'));
    await tester.pumpAndSettle();

    final prefs = AppPrefs.instance;
    expect(prefs.get(StoryboardPrefs.layout, projectId: 3), 'list');
    expect(prefs.get(StoryboardPrefs.layout), 'linear');
    // Marca de «Proyecto» en la fila y recuento en el lateral.
    expect(find.text('Proyecto'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);

    // Volver al valor general.
    await tester.tap(find.text('Proyecto'));
    await tester.pumpAndSettle();
    expect(prefs.hasOverride(StoryboardPrefs.layout, 3), isFalse);
    expect(find.text('Proyecto'), findsNothing);
  });

  testWidgets('el buscador filtra el lateral', (tester) async {
    await pump(tester);
    await tester.enterText(find.byType(TextField), 'rejilla');
    await tester.pumpAndSettle();
    expect(find.text('Acerca de'), findsNothing);
  });
}
