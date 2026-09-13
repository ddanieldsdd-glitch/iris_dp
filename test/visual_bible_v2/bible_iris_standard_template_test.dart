import 'package:flutter_test/flutter_test.dart';
import 'package:iris_dp/features/visual_bible/v2/layout/page_layout_recipe_registry.dart';
import 'package:iris_dp/features/visual_bible/v2/templates/bible_iris_standard_template.dart';
import 'package:iris_dp/features/visual_bible/v2/templates/bible_v2_professional_templates.dart';
import 'package:iris_dp/features/visual_bible/v2/theme/bible_theme.dart';

void main() {
  test('IRIS Estándar tiene 4 grupos y 13 apartados con recetas', () {
    final pack = BibleIrisStandardTemplate.package;
    final doc = pack.document!;
    expect(pack.id, BibleIrisStandardTemplate.id);
    expect(pack.legacyBundle, isNull);
    expect(doc.themeId, BibleThemeIds.irisStandard);
    expect(doc.groups, hasLength(4));
    expect(doc.pages, hasLength(13));
    expect(
      doc.pages.map((p) => p.id).toSet(),
      containsAll([
        'direction',
        'concept',
        'camera',
        'optics',
        'exposure',
        'lighting',
        'color_image',
        'format',
        'texture',
        'location',
        'camera_tests',
        'workflow',
        'moodboard',
      ]),
    );
    for (final page in doc.pages) {
      expect(page.layoutRecipeId, isNotNull);
      expect(
        page.layoutRecipeId,
        PageLayoutRecipeRegistry.recipeIdForSection(page.id),
      );
      expect(page.blocks, isNotEmpty);
    }
  });

  test('Dirección IRIS no incluye Key Frame y usa widgets Stitch', () {
    final page = BibleIrisStandardTemplate.package.document!.pages.firstWhere(
      (p) => p.id == 'direction',
    );
    expect(
      page.blocks.any((b) => b.content['fieldKey'] == 'keyFrame'),
      isFalse,
    );
    expect(
      page.blocks.map((b) => b.content['subsectionKind']),
      containsAll([
        'narrativeIntent',
        'tonePoints',
        'visualStrategy',
        'acts',
        'transitions',
        'narrativeRefs',
      ]),
    );
  });

  test('Moodboard IRIS sigue siendo página de bloques moodboardRefs', () {
    final page = BibleIrisStandardTemplate.package.document!.pages
        .firstWhere((p) => p.id == 'moodboard');
    expect(page.isHidden, isFalse);
    expect(
      page.blocks.map((b) => b.content['subsectionKind']),
      contains('moodboardRefs'),
    );
    expect(
      page.blocks.any((b) => b.content['subsectionKind'] == 'narrativeRefs'),
      isFalse,
    );
  });

  test('IRIS Estándar es la plantilla profesional por defecto', () {
    expect(
      BibleV2ProfessionalTemplates.available.single.id,
      BibleIrisStandardTemplate.id,
    );
    expect(
      BibleV2ProfessionalTemplates.isAvailable(
        BibleV2ProfessionalTemplates.irisStandard,
      ),
      isTrue,
    );
  });
}
