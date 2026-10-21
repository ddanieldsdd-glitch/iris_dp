import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iris_dp/core/database/app_database.dart';
import 'package:iris_dp/core/database/database_provider.dart';
import 'package:iris_dp/core/theme/app_theme.dart';
import 'package:iris_dp/features/equipment/widgets/light_quick_add_sheet.dart';

void main() {
  late AppDatabase db;
  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });
  tearDown(() => db.close());

  testWidgets('elegir tubo, marca, modelo y vatios da de alta la luz', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    Light? created;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          theme: AppTheme.dark,
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () async => created = await showLightQuickAdd(context),
              child: const Text('abrir'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();

    // Sin marca ni vatios no se puede guardar.
    final save = find.byKey(const Key('quick-add-save'));
    expect(tester.widget<FilledButton>(save).onPressed, isNull);

    await tester.tap(find.byKey(const ValueKey('format-tube')));
    await tester.enterText(find.byKey(const Key('brand')), 'Astera');
    await tester.enterText(find.byKey(const Key('model')), 'Titan X2');
    await tester.enterText(find.byKey(const Key('watts')), '48');
    await tester.tap(find.text('RGB'));
    await tester.pump();

    expect(find.text('led_tube'), findsOneWidget);
    expect(find.text('astera_titan_x2'), findsOneWidget);
    expect(find.text('en todas direcciones'), findsOneWidget);

    // Con todo, se puede guardar. (Guardar lo prueba light_catalog_test:
    // aquí la base en memoria y las fuentes de la app no conviven.)
    expect(tester.widget<FilledButton>(save).onPressed, isNotNull);
    expect(created, isNull);
  });
}
