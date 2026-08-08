import 'package:flutter_test/flutter_test.dart';
import 'package:iris_dp/features/visual_bible/v2/layout/page_layout_recipe_registry.dart';
import 'package:iris_dp/features/visual_bible/v2/model/bible_document.dart';
import 'package:iris_dp/features/visual_bible/v2/model/bible_page.dart';
import 'package:iris_dp/features/visual_bible/v2/model/bible_page_mode.dart';
import 'package:iris_dp/features/visual_bible/v2/renderer/bible_page_renderer.dart';

void main() {
  test('renderer expone receta activa en modo recipe', () {
    final page = BiblePage(
      id: 'direction',
      groupId: 'narrative',
      label: 'Dirección',
      legacySectionId: 'direction',
      layoutRecipeId: PageLayoutRecipeRegistry.directionBento,
      pageMode: BiblePageMode.recipe,
    );

    final renderer = BiblePageRenderer(
      page: page,
      document: BibleDocument(
        projectId: 1,
        updatedAt: DateTime.utc(2026, 1, 1),
      ),
    );

    expect(renderer.activeRecipe?.id, PageLayoutRecipeRegistry.directionBento);
  });
}
