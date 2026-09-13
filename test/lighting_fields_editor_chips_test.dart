import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iris_dp/core/database/app_database.dart';
import 'package:iris_dp/core/theme/app_theme.dart';
import 'package:iris_dp/features/visual_bible/widgets/bible_section_fields_editor.dart';
import 'package:iris_dp/shared/visual_bible/bible_section_fields.dart';
import 'package:iris_dp/shared/visual_bible/bible_section_ids.dart';
import 'package:iris_dp/shared/visual_bible/bible_stitch_module_registry.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('editor Iluminación muestra chip Cinematic/Technical', (
    tester,
  ) async {
    final fields = [
      ...BibleSectionFieldsConfig.defaultsFor(BibleSectionId.lighting),
      BibleStitchModuleRegistry.module(
        BibleSectionId.lighting,
        'diagrams',
      )!.toField(),
    ];
    final definition = BibleSectionDefinition(
      id: BibleSectionId.lighting,
      bibleId: 1,
      groupId: 'technical',
      label: 'Iluminación',
      iconKey: 'wb_sunny',
      sortOrder: 0,
      isBuiltIn: true,
      isHidden: false,
      template: 'blocks_lighting',
      contentJson: BibleSectionFieldsConfig.encode(fields),
    );

    await tester.binding.setSurfaceSize(const Size(900, 3200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(
          body: BibleSectionFieldsEditor(
            bibleId: 1,
            definition: definition,
            embedded: true,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Cinematic'), findsWidgets);
    expect(find.text('Technical'), findsWidgets);
    expect(find.text('Sensación de temperatura'), findsOneWidget);
    expect(find.textContaining('Mosaico de contenedores'), findsWidgets);
    expect(find.textContaining('Lista de setups'), findsWidgets);
    expect(find.textContaining('Panel de telemetría'), findsWidgets);
  });
}
