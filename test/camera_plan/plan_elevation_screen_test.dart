import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:iris_dp/core/theme/app_theme.dart';
import 'package:iris_dp/features/camera_plan/plan_elevation_screen.dart';

import '../support/snapshot.dart';

void main() {
  testWidgets('los interruptores de la hoja caben en un iPhone', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'iris_light_sheet_beams': false});
    await loadSnapshotFonts();
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: const PlanElevationScreen(
          elements: [],
          metersPerUnit: 0.02,
          name: 'Prueba',
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    for (final label in [
      'Conos de luz',
      'Manchas en el suelo',
      'Personas y cámaras',
      'Números',
      'Alzado y perfil',
    ]) {
      expect(find.text(label), findsWidgets, reason: label);
    }
    expect(find.text('La planta está vacía.'), findsOneWidget);
    // Lo guardado manda: los conos salen apagados.
    final cones = tester.widget<FilterChip>(
      find.widgetWithText(FilterChip, 'Conos de luz'),
    );
    expect(cones.selected, isFalse);
    expect(tester.takeException(), isNull);
    await saveSnapshot(tester, 'alzado_interruptores_iphone');
  });
}
