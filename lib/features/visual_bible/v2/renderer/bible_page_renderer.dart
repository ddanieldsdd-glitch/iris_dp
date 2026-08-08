import 'package:flutter/material.dart';

import '../layout/page_layout_recipe.dart';
import '../layout/page_layout_recipe_registry.dart';
import '../model/bible_document.dart';
import '../model/bible_page.dart';
import '../model/bible_page_mode.dart';
import '../theme/bible_theme.dart';
import '../widgets/bible_block_compositor.dart';

/// Modo de renderizado compartido (lectura, edición, preview, export UI).
enum BiblePageRenderMode { view, edit, preview, export }

/// Renderer unificado: recetas Stitch vía [sectionBuilder] o bloques freeform.
class BiblePageRenderer extends StatelessWidget {
  final BiblePage page;
  final BibleDocument document;
  final BiblePageRenderMode mode;
  final int? projectId;
  final int? bibleId;

  /// Construye la pantalla Stitch cuando la página usa una receta profesional.
  final Widget Function(String sectionId)? sectionBuilder;

  /// Inspector / selección en modo edición.
  final ValueChanged<String?>? onBlockSelected;
  final String? selectedBlockId;

  const BiblePageRenderer({
    super.key,
    required this.page,
    required this.document,
    this.mode = BiblePageRenderMode.view,
    this.projectId,
    this.bibleId,
    this.sectionBuilder,
    this.onBlockSelected,
    this.selectedBlockId,
  });

  @override
  Widget build(BuildContext context) {
    if (page.pageMode == BiblePageMode.recipe) {
      final sectionId = page.legacySectionId ?? page.id;
      final builder = sectionBuilder;
      if (builder != null && sectionId.isNotEmpty) {
        return builder(sectionId);
      }
    }

    final theme = page.themeId != null
        ? document.themes
              .where((t) => t.id == page.themeId)
              .cast<BibleTheme?>()
              .firstOrNull ??
          BibleTheme.builtin(page.themeId!)
        : document.resolvedTheme;

    return BibleBlockCompositor(
      blocks: page.blocks,
      theme: theme,
      projectId: projectId ?? document.projectId,
      editing: mode == BiblePageRenderMode.edit,
      selectedBlockId: selectedBlockId,
      onSelect: onBlockSelected == null
          ? null
          : (id) => onBlockSelected!(id),
    );
  }

  /// Metadatos de receta para inspector / plantillas.
  PageLayoutRecipe? get activeRecipe =>
      PageLayoutRecipeRegistry.byId(page.layoutRecipeId);
}

extension _FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull {
    final it = iterator;
    return it.moveNext() ? it.current : null;
  }
}
