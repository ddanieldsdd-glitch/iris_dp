import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:iris_dp/core/theme/app_theme.dart';
import 'package:iris_dp/core/widgets/safe_reorderable_column.dart';

/// Lista como las de la app: filas con botones que llevan aviso emergente,
/// dentro de un `Scaffold`.
class _Host extends StatefulWidget {
  const _Host();

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  final items = ['Uno', 'Dos', 'Tres', 'Cuatro'];

  Widget _tile(String item) => ListTile(
    title: Text(item),
    trailing: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: 'Renombrar $item',
          icon: const Icon(Icons.edit_outlined),
          onPressed: () {},
        ),
        const SizedBox(width: 40),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: AppTheme.dark,
      home: Scaffold(
        body: SafeReorderableColumn(
          itemCount: items.length,
          keyOf: (i) => ValueKey(items[i]),
          dragLabel: (i) => items[i],
          onReorder: (o, n) =>
              setState(() => items.insert(n, items.removeAt(o))),
          itemBuilder: (context, i) => _tile(items[i]),
        ),
      ),
    );
  }
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 20; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Deja el aviso de un botón a la vista y arrastra la primera fila hasta
/// debajo de la tercera, con ratón.
Future<void> _hoverThenDrag(WidgetTester tester) async {
  final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
  await mouse.addPointer(location: Offset.zero);
  await mouse.moveTo(tester.getCenter(find.byTooltip('Renombrar Dos')));
  await _settle(tester);

  final handles = find.byIcon(Icons.drag_handle);
  final from = tester.getCenter(handles.at(0));
  final to = tester.getCenter(find.text('Cuatro'));
  await mouse.moveTo(from);
  await tester.pump(const Duration(milliseconds: 50));
  await mouse.down(from);
  await tester.pump(const Duration(milliseconds: 50));
  for (var i = 1; i <= 12; i++) {
    await mouse.moveTo(Offset(from.dx, from.dy + (to.dy - from.dy) * i / 12));
    await tester.pump(const Duration(milliseconds: 30));
  }
  await mouse.up();
  await _settle(tester);
  await mouse.removePointer();
}

void main() {
  testWidgets('reordenar filas con avisos emergentes no rompe la pantalla', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const _Host());
    await _settle(tester);
    await _hoverThenDrag(tester);

    expect(tester.takeException(), isNull);
    final state = tester.state<_HostState>(find.byType(_Host));
    expect(state.items, ['Dos', 'Tres', 'Uno', 'Cuatro']);
    // Las filas siguen ahí, con sus botones.
    expect(find.byTooltip('Renombrar Uno'), findsOneWidget);
  });

  testWidgets('soltar bajo la última fila la lleva al final', (tester) async {
    tester.view.physicalSize = const Size(900, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const _Host());
    await _settle(tester);

    final from = tester.getCenter(find.byIcon(Icons.drag_handle).at(0));
    final last = tester.getRect(find.text('Cuatro'));
    final gesture = await tester.startGesture(from);
    await tester.pump(const Duration(milliseconds: 50));
    for (var i = 1; i <= 10; i++) {
      await gesture.moveTo(
        Offset(from.dx, from.dy + (last.bottom + 30 - from.dy) * i / 10),
      );
      await tester.pump(const Duration(milliseconds: 30));
    }
    await gesture.up();
    await _settle(tester);

    expect(tester.takeException(), isNull);
    final state = tester.state<_HostState>(find.byType(_Host));
    expect(state.items, ['Dos', 'Tres', 'Cuatro', 'Uno']);
  });
}
