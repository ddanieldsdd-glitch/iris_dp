import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iris_dp/core/theme/app_theme.dart';
import 'package:iris_dp/features/visual_bible/bible_blueprint.dart';
import 'package:iris_dp/features/visual_bible/widgets/bible_section_shared_widgets.dart';

void main() {
  testWidgets('dropdown no rompe con estilo technical persistido', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(
          body: BibleSectionModeDropdown(
            value: BibleVisualMode.technical,
            onChanged: (_) {},
          ),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.text('Technical'), findsOneWidget);
  });
}
