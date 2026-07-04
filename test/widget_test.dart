import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:iris_dp/main.dart';

void main() {
  testWidgets('Projects screen renders empty state', (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const ProviderScope(child: IrisDPApp()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('IRIS DP'), findsOneWidget);
    expect(find.text('Proyectos'), findsOneWidget);
    expect(find.text('Sin proyectos'), findsOneWidget);
    expect(find.text('Nuevo proyecto'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 100));
  });
}
