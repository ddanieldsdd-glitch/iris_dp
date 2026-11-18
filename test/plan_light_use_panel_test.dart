import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iris_dp/core/theme/app_theme.dart';
import 'package:iris_dp/features/camera_plan/plan_light_use_panel.dart';

/// PL.2: el panel rápido de focos de un plano.
void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  Future<List<Set<String>>> open(
    WidgetTester tester, {
    Set<String> unused = const {},
    Set<String>? previous,
  }) async {
    final applied = <Set<String>>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(
          body: PlanLightUsePanel(
            title: 'Focos de este plano',
            lights: const [
              (uid: 'a', name: 'Tubo 15X', where: ''),
              (uid: 'b', name: 'Panel 60', where: ''),
              (uid: 'c', name: 'Farola', where: 'Del entorno'),
            ],
            unused: unused,
            previous: previous,
            previousLabel: previous == null ? null : 'el plano 2',
            onApply: (u) async => applied.add(u),
          ),
        ),
      ),
    );
    return applied;
  }

  testWidgets('una casilla deja de usar un foco al momento', (tester) async {
    final applied = await open(tester);
    expect(
      find.text(
        'Usa 3 de 3. Los que no usa se quedan en el set, en '
        'fantasma. En la planta, la tecla U.',
      ),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('light-use-b')));
    await tester.pump();
    expect(applied.single, {'b'});
    expect(find.textContaining('Usa 2 de 3'), findsOneWidget);
  });

  testWidgets('ninguno, todos e igual que el anterior', (tester) async {
    final applied = await open(tester, unused: {'a'}, previous: {'c'});
    await tester.tap(find.byKey(const ValueKey('light-use-none')));
    await tester.pump();
    expect(applied.last, {'a', 'b', 'c'});
    await tester.tap(find.byKey(const ValueKey('light-use-all')));
    await tester.pump();
    expect(applied.last, isEmpty);
    expect(find.text('Igual que el plano 2'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('light-use-previous')));
    await tester.pump();
    expect(applied.last, {'c'});
  });
}
