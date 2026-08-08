import 'dart:math';

import '../model/bible_block.dart';
import '../../bible_block_catalog.dart';
import '../model/bible_document.dart';
import '../model/bible_page.dart';
import '../persistence/bible_document_store.dart';
import '../theme/bible_theme.dart';
import 'bible_template_package.dart';

/// Aplica plantillas V2 mediante deep clone (sin legacy blueprint/layout).
class BibleTemplateApplyService {
  BibleTemplateApplyService(this._store);

  final BibleDocumentStore _store;

  /// Clona [package] dentro de la biblia actual, regenerando IDs.
  Future<BibleDocument> applyPackage({
    required BibleTemplatePackage package,
    required int bibleId,
    required int projectId,
    bool includeContent = true,
    bool includeImages = true,
  }) async {
    final source = package.document;
    if (source == null) {
      throw StateError('Plantilla ${package.id} no incluye documento V2');
    }

    final cloned = _cloneDocument(
      source: source,
      bibleId: bibleId,
      projectId: projectId,
      themeId: package.theme?.id ?? source.themeId,
      themes: package.theme != null
          ? [package.theme!]
          : source.themes,
      exportSettings: package.exportSettings.isNotEmpty
          ? package.exportSettings
          : source.exportSettings,
      includeContent: includeContent,
      includeImages: includeImages,
    );

    await _store.save(cloned);
    await _store.snapshotVersion(
      bibleId: bibleId,
      doc: cloned,
      label: 'template_${package.id}',
      note: 'Plantilla aplicada: ${package.name}',
    );
    return cloned;
  }

  /// Guarda el documento actual como plantilla de usuario.
  BibleTemplatePackage saveAsPackage({
    required BibleDocument document,
    required String id,
    required String name,
    required String description,
    String category = 'custom',
    String author = 'Usuario',
  }) {
    return BibleTemplatePackage(
      id: id,
      name: name,
      description: description,
      author: author,
      category: category,
      document: _cloneDocument(
        source: document,
        bibleId: document.bibleId,
        projectId: document.projectId,
        themeId: document.themeId,
        themes: document.themes,
        exportSettings: document.exportSettings,
        includeContent: true,
        includeImages: true,
      ),
      theme: document.resolvedTheme,
      exportSettings: Map<String, dynamic>.from(document.exportSettings),
      createdAt: DateTime.now().toUtc(),
    );
  }

  BibleDocument _cloneDocument({
    required BibleDocument source,
    required int? bibleId,
    required int projectId,
    required String themeId,
    required List<BibleTheme> themes,
    required Map<String, dynamic> exportSettings,
    required bool includeContent,
    required bool includeImages,
  }) {
    final rng = Random();
    final pageIdMap = <String, String>{};

    String newId(String prefix) =>
        '${prefix}_${DateTime.now().millisecondsSinceEpoch}_${rng.nextInt(99999)}';

    final pages = source.pages.map((page) {
      final newPageId = newId('page');
      pageIdMap[page.id] = newPageId;
      final blocks = page.blocks.map((block) {
        final content = includeContent
            ? _cloneContent(block.content, includeImages: includeImages)
            : _emptyContent(block.type);
        return block.copyWith(
          id: newId('block'),
          content: content,
        );
      }).toList();
      return page.copyWith(id: newPageId, blocks: blocks);
    }).toList();

    return BibleDocument(
      bibleId: bibleId,
      projectId: projectId,
      themeId: themeId,
      themes: themes.map((t) => t.copyWith()).toList(),
      groups: source.groups,
      pages: pages,
      exportSettings: Map<String, dynamic>.from(exportSettings),
      navigation: {
        if (pages.isNotEmpty) 'lastPageId': pages.first.id,
      },
      updatedAt: DateTime.now().toUtc(),
    );
  }

  Map<String, dynamic> _cloneContent(
    Map<String, dynamic> content, {
    required bool includeImages,
  }) {
    final map = Map<String, dynamic>.from(content);
    if (!includeImages) {
      map.remove('imagePath');
      map.remove('images');
      map.remove('image');
    }
    return map;
  }

  Map<String, dynamic> _emptyContent(BibleBlockKind type) => switch (type) {
    BibleBlockKind.narrative => {'text': '', 'label': 'Intención'},
    BibleBlockKind.text => {'text': ''},
    _ => {'label': type.label},
  };
}
