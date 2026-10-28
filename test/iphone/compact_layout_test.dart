import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:iris_dp/core/theme/app_layout.dart';
import 'package:iris_dp/core/theme/app_theme.dart';
import 'package:iris_dp/core/widgets/compact_nav_shell.dart';
import 'package:iris_dp/features/project_hub/project_hub_destinations.dart';
import 'package:iris_dp/features/project_hub/project_hub_screen.dart';
import 'package:iris_dp/features/projects/projects_header.dart';

/// iPhone 14/15/16: 390 × 844 pt (docs/PLAN_IPHONE.md, IP.1).
const _iphone = Size(390, 844);
const _ipad = Size(1024, 768);

Future<void> _pump(WidgetTester tester, Size size, Widget child) async {
  // La vista (y con ella MediaQuery) a tamaño de iPhone en puntos.
  tester.view.devicePixelRatio = 3;
  tester.view.physicalSize = size * 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(theme: AppTheme.dark, home: child));
  await tester.pump();
}

List<CompactNavTab> _tabs(List<String> built) => [
  for (final name in ['Proyecto', 'Rodaje', 'Storyboard'])
    CompactNavTab(
      label: name,
      icon: Icons.circle_outlined,
      builder: (_) {
        built.add(name);
        return Center(child: Text('pantalla $name'));
      },
    ),
];

void main() {
  group('AppLayout · corte compacto (IP.1.1)', () {
    test('390 es compacto, 768 medio y 1024 ancho', () {
      expect(AppLayout.sizeClassFor(390), AppSizeClass.compact);
      expect(AppLayout.sizeClassFor(599), AppSizeClass.compact);
      expect(AppLayout.sizeClassFor(600), AppSizeClass.medium);
      expect(AppLayout.sizeClassFor(768), AppSizeClass.medium);
      expect(AppLayout.sizeClassFor(1024), AppSizeClass.wide);
    });

    testWidgets('isCompact, margen y ancho de diálogo a 390', (tester) async {
      late BuildContext ctx;
      await _pump(
        tester,
        _iphone,
        Builder(
          builder: (c) {
            ctx = c;
            return const SizedBox();
          },
        ),
      );
      expect(AppLayout.isCompact(ctx), isTrue);
      expect(AppLayout.isTablet(ctx), isFalse);
      expect(AppLayout.gutter(ctx), AppLayout.compactGutter);
      // 390 − 2·40 − 2·24 = 262: un diálogo de 340 se recorta.
      expect(AppLayout.dialogWidth(ctx, 340), 262);
      expect(AppLayout.dialogWidth(ctx, 200), 200);
    });

    testWidgets('en iPad nada cambia', (tester) async {
      late BuildContext ctx;
      await _pump(
        tester,
        _ipad,
        Builder(
          builder: (c) {
            ctx = c;
            return const SizedBox();
          },
        ),
      );
      expect(AppLayout.isCompact(ctx), isFalse);
      expect(AppLayout.gutter(ctx), 32);
      expect(AppLayout.dialogWidth(ctx, 340), 340);
    });
  });

  group('CompactNavShell · barra inferior (IP.1.2)', () {
    testWidgets('a 390 muestra la barra y cambia de pestaña', (tester) async {
      final built = <String>[];
      await _pump(tester, _iphone, CompactNavShell(tabs: _tabs(built)));

      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.text('pantalla Proyecto'), findsOneWidget);
      // Las pestañas no visitadas no se construyen.
      expect(built, ['Proyecto']);

      await tester.tap(find.text('Storyboard'));
      await tester.pumpAndSettle();
      expect(find.text('pantalla Storyboard'), findsOneWidget);
      expect(built, containsAll(['Proyecto', 'Storyboard']));
      expect(built, isNot(contains('Rodaje')));

      // Al volver, la primera sigue viva (no se reconstruye desde cero).
      await tester.tap(find.text('Proyecto'));
      await tester.pumpAndSettle();
      expect(find.text('pantalla Proyecto'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('en iPad no hay barra: solo la primera pantalla', (
      tester,
    ) async {
      final built = <String>[];
      await _pump(tester, _ipad, CompactNavShell(tabs: _tabs(built)));

      expect(find.byType(NavigationBar), findsNothing);
      expect(find.text('pantalla Proyecto'), findsOneWidget);
      expect(built, ['Proyecto']);
    });

    test('las pestañas del hub son los módulos de set, sin repetir', () {
      final ids = compactHubTabs.map((t) => t.id).toList();
      expect(ids.toSet().length, ids.length);
      expect(ids.first, ProjectHubDestinationId.dailyOrder);
      expect(ids, contains(ProjectHubDestinationId.storyboard));
      expect(ids, contains(ProjectHubDestinationId.cameraPlans));
      // Hub + pestañas: NavigationBar admite como mucho 5.
      expect(compactHubTabs.length + 1, lessThanOrEqualTo(5));
    });
  });

  group('ProjectsHeader (IP.1.3)', () {
    Widget header(List<String> taps) => Scaffold(
      body: Column(
        children: [
          ProjectsHeader(
            statusActions: [
              IconButton(
                icon: const Icon(Icons.settings_outlined),
                onPressed: () {},
              ),
              const SizedBox(width: 36, height: 36),
              const CircleAvatar(radius: 16),
            ],
            onNewProject: () => taps.add('proyecto'),
            onNewGroup: () => taps.add('grupo'),
          ),
        ],
      ),
    );

    testWidgets('a 390 cabe y los botones van en el menú «+»', (tester) async {
      final taps = <String>[];
      await _pump(tester, _iphone, header(taps));

      expect(tester.takeException(), isNull, reason: 'sin desbordes');
      expect(find.text('Nuevo proyecto'), findsNothing);

      await tester.tap(find.byTooltip('Nuevo'));
      await tester.pumpAndSettle();
      expect(find.text('Nuevo grupo'), findsOneWidget);
      await tester.tap(find.text('Nuevo proyecto'));
      await tester.pumpAndSettle();
      expect(taps, ['proyecto']);
    });

    testWidgets('en escritorio siguen los dos botones con texto', (
      tester,
    ) async {
      final taps = <String>[];
      await _pump(tester, const Size(1200, 800), header(taps));

      expect(find.byTooltip('Nuevo'), findsNothing);
      expect(find.text('Nuevo grupo'), findsOneWidget);
      await tester.tap(find.text('Nuevo proyecto'));
      expect(taps, ['proyecto']);
    });
  });

  group('Hub del proyecto a 390 (IP.1.4)', () {
    testWidgets('las tarjetas de módulo caben en una columna', (tester) async {
      // Mismo cálculo que el hub: una columna, aspecto 2.0, margen 16.
      const width = 390.0 - 2 * AppLayout.compactGutter;
      const stats = ProjectHubStats(sceneCount: 12, planCount: 3);
      await _pump(
        tester,
        _iphone,
        Scaffold(
          body: ListView(
            children: [
              for (final d in buildProjectHubDestinations())
                Center(
                  child: SizedBox(
                    width: width,
                    height: width / 2.0,
                    child: ProjectHubCard(
                      destination: d,
                      stats: stats,
                      onTap: () {},
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
      expect(tester.takeException(), isNull, reason: 'sin desbordes');
      expect(find.text('Guion literario'), findsOneWidget);
    });
  });
}
