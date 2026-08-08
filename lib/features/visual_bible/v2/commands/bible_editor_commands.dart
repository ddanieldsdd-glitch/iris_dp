import '../model/bible_block.dart';
import '../model/bible_block_layout.dart';
import '../model/bible_block_style.dart';
import '../model/bible_document.dart';
import '../model/bible_page.dart';
import '../../bible_block_catalog.dart';

/// Contrato de comando sobre [BibleDocument] (Undo/Redo / autosave).
abstract class BibleEditorCommand {
  String get label;
  BibleDocument apply(BibleDocument doc);
  BibleDocument undo(BibleDocument doc);
}

class AddBlockCommand implements BibleEditorCommand {
  final String pageId;
  final BibleBlock block;
  final int? index;

  AddBlockCommand({required this.pageId, required this.block, this.index});

  @override
  String get label => 'Añadir bloque';

  @override
  BibleDocument apply(BibleDocument doc) {
    return _updatePage(doc, pageId, (page) {
      final blocks = List<BibleBlock>.from(page.blocks);
      final i = index ?? blocks.length;
      blocks.insert(i.clamp(0, blocks.length), block);
      return page.copyWith(blocks: blocks);
    });
  }

  @override
  BibleDocument undo(BibleDocument doc) {
    return _updatePage(doc, pageId, (page) {
      return page.copyWith(
        blocks: page.blocks.where((b) => b.id != block.id).toList(),
      );
    });
  }
}

class DeleteBlockCommand implements BibleEditorCommand {
  final String pageId;
  final BibleBlock removed;
  final int index;

  DeleteBlockCommand({
    required this.pageId,
    required this.removed,
    required this.index,
  });

  @override
  String get label => 'Eliminar bloque';

  @override
  BibleDocument apply(BibleDocument doc) {
    return _updatePage(doc, pageId, (page) {
      return page.copyWith(
        blocks: page.blocks.where((b) => b.id != removed.id).toList(),
      );
    });
  }

  @override
  BibleDocument undo(BibleDocument doc) {
    return _updatePage(doc, pageId, (page) {
      final blocks = List<BibleBlock>.from(page.blocks);
      final i = index.clamp(0, blocks.length);
      blocks.insert(i, removed);
      return page.copyWith(blocks: blocks);
    });
  }
}

class MoveBlockCommand implements BibleEditorCommand {
  final String pageId;
  final String blockId;
  final BibleBlockLayout from;
  final BibleBlockLayout to;

  MoveBlockCommand({
    required this.pageId,
    required this.blockId,
    required this.from,
    required this.to,
  });

  @override
  String get label => 'Mover bloque';

  @override
  BibleDocument apply(BibleDocument doc) =>
      _mapBlock(doc, pageId, blockId, (b) => b.copyWith(layout: to));

  @override
  BibleDocument undo(BibleDocument doc) =>
      _mapBlock(doc, pageId, blockId, (b) => b.copyWith(layout: from));
}

class ResizeBlockCommand implements BibleEditorCommand {
  final String pageId;
  final String blockId;
  final BibleBlockLayout from;
  final BibleBlockLayout to;

  ResizeBlockCommand({
    required this.pageId,
    required this.blockId,
    required this.from,
    required this.to,
  });

  @override
  String get label => 'Redimensionar bloque';

  @override
  BibleDocument apply(BibleDocument doc) =>
      _mapBlock(doc, pageId, blockId, (b) => b.copyWith(layout: to));

  @override
  BibleDocument undo(BibleDocument doc) =>
      _mapBlock(doc, pageId, blockId, (b) => b.copyWith(layout: from));
}

class UpdateBlockContentCommand implements BibleEditorCommand {
  final String pageId;
  final String blockId;
  final Map<String, dynamic> from;
  final Map<String, dynamic> to;

  UpdateBlockContentCommand({
    required this.pageId,
    required this.blockId,
    required this.from,
    required this.to,
  });

  @override
  String get label => 'Editar contenido';

  @override
  BibleDocument apply(BibleDocument doc) =>
      _mapBlock(doc, pageId, blockId, (b) => b.copyWith(content: to));

  @override
  BibleDocument undo(BibleDocument doc) =>
      _mapBlock(doc, pageId, blockId, (b) => b.copyWith(content: from));
}

class UpdateBlockStyleCommand implements BibleEditorCommand {
  final String pageId;
  final String blockId;
  final BibleBlockStyle from;
  final BibleBlockStyle to;

  UpdateBlockStyleCommand({
    required this.pageId,
    required this.blockId,
    required this.from,
    required this.to,
  });

  @override
  String get label => 'Cambiar estilo';

  @override
  BibleDocument apply(BibleDocument doc) =>
      _mapBlock(doc, pageId, blockId, (b) => b.copyWith(style: to));

  @override
  BibleDocument undo(BibleDocument doc) =>
      _mapBlock(doc, pageId, blockId, (b) => b.copyWith(style: from));
}

class DuplicateBlockCommand implements BibleEditorCommand {
  final String pageId;
  final BibleBlock original;
  final BibleBlock duplicate;

  DuplicateBlockCommand({
    required this.pageId,
    required this.original,
    required this.duplicate,
  });

  factory DuplicateBlockCommand.create({
    required String pageId,
    required BibleBlock original,
    required String newId,
  }) {
    final dup = original.copyWith(
      id: newId,
      layout: original.layout.copyWith(row: original.layout.row + 1),
    );
    return DuplicateBlockCommand(
      pageId: pageId,
      original: original,
      duplicate: dup,
    );
  }

  @override
  String get label => 'Duplicar bloque';

  @override
  BibleDocument apply(BibleDocument doc) {
    return _updatePage(doc, pageId, (page) {
      final blocks = List<BibleBlock>.from(page.blocks);
      final idx = blocks.indexWhere((b) => b.id == original.id);
      blocks.insert(idx < 0 ? blocks.length : idx + 1, duplicate);
      return page.copyWith(blocks: blocks);
    });
  }

  @override
  BibleDocument undo(BibleDocument doc) {
    return _updatePage(doc, pageId, (page) {
      return page.copyWith(
        blocks: page.blocks.where((b) => b.id != duplicate.id).toList(),
      );
    });
  }
}

class ChangeBlockTypeCommand implements BibleEditorCommand {
  final String pageId;
  final String blockId;
  final BibleBlockKind from;
  final BibleBlockKind to;

  ChangeBlockTypeCommand({
    required this.pageId,
    required this.blockId,
    required this.from,
    required this.to,
  });

  @override
  String get label => 'Cambiar tipo de bloque';

  @override
  BibleDocument apply(BibleDocument doc) =>
      _mapBlock(doc, pageId, blockId, (b) => b.copyWith(type: to));

  @override
  BibleDocument undo(BibleDocument doc) =>
      _mapBlock(doc, pageId, blockId, (b) => b.copyWith(type: from));
}

class AddPageCommand implements BibleEditorCommand {
  final BiblePage page;

  AddPageCommand(this.page);

  @override
  String get label => 'Añadir página';

  @override
  BibleDocument apply(BibleDocument doc) =>
      doc.copyWith(pages: [...doc.pages, page]);

  @override
  BibleDocument undo(BibleDocument doc) =>
      doc.copyWith(pages: doc.pages.where((p) => p.id != page.id).toList());
}

class DeletePageCommand implements BibleEditorCommand {
  final BiblePage removed;
  final int index;

  DeletePageCommand({required this.removed, required this.index});

  @override
  String get label => 'Eliminar página';

  @override
  BibleDocument apply(BibleDocument doc) =>
      doc.copyWith(pages: doc.pages.where((p) => p.id != removed.id).toList());

  @override
  BibleDocument undo(BibleDocument doc) {
    final pages = List<BiblePage>.from(doc.pages);
    pages.insert(index.clamp(0, pages.length), removed);
    return doc.copyWith(pages: pages);
  }
}

class DuplicatePageCommand implements BibleEditorCommand {
  final String sourcePageId;
  final BiblePage duplicate;

  DuplicatePageCommand({required this.sourcePageId, required this.duplicate});

  factory DuplicatePageCommand.create({
    required BibleDocument doc,
    required String sourcePageId,
    required String newPageId,
  }) {
    final source = doc.pageById(sourcePageId)!;
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final blocks = source.blocks
        .map(
          (b) => b.copyWith(
            id: 'block_${stamp}_${b.id}',
            layout: b.layout.copyWith(row: b.layout.row + 1),
          ),
        )
        .toList();
    return DuplicatePageCommand(
      sourcePageId: sourcePageId,
      duplicate: source.copyWith(
        id: newPageId,
        label: '${source.label} (copia)',
        sortOrder: source.sortOrder + 1,
        blocks: blocks,
      ),
    );
  }

  @override
  String get label => 'Duplicar página';

  @override
  BibleDocument apply(BibleDocument doc) {
    final idx = doc.pages.indexWhere((p) => p.id == sourcePageId);
    final pages = List<BiblePage>.from(doc.pages);
    pages.insert(idx < 0 ? pages.length : idx + 1, duplicate);
    return doc.copyWith(pages: pages);
  }

  @override
  BibleDocument undo(BibleDocument doc) =>
      doc.copyWith(pages: doc.pages.where((p) => p.id != duplicate.id).toList());
}

class RenamePageCommand implements BibleEditorCommand {
  final String pageId;
  final String fromLabel;
  final String toLabel;

  RenamePageCommand({
    required this.pageId,
    required this.fromLabel,
    required this.toLabel,
  });

  @override
  String get label => 'Renombrar página';

  @override
  BibleDocument apply(BibleDocument doc) => _updatePage(
    doc,
    pageId,
    (p) => p.copyWith(label: toLabel),
  );

  @override
  BibleDocument undo(BibleDocument doc) => _updatePage(
    doc,
    pageId,
    (p) => p.copyWith(label: fromLabel),
  );
}

class ReorderPagesCommand implements BibleEditorCommand {
  final List<BiblePage> fromOrder;
  final List<BiblePage> toOrder;

  ReorderPagesCommand({required this.fromOrder, required this.toOrder});

  @override
  String get label => 'Reordenar páginas';

  @override
  BibleDocument apply(BibleDocument doc) => doc.copyWith(pages: toOrder);

  @override
  BibleDocument undo(BibleDocument doc) => doc.copyWith(pages: fromOrder);
}

class ApplyDocumentCommand implements BibleEditorCommand {
  final BibleDocument previous;
  final BibleDocument next;

  ApplyDocumentCommand({required this.previous, required this.next});

  @override
  String get label => 'Aplicar plantilla';

  @override
  BibleDocument apply(BibleDocument doc) => next.copyWith(
    bibleId: doc.bibleId,
    projectId: doc.projectId,
  );

  @override
  BibleDocument undo(BibleDocument doc) => previous;
}

class UpdateThemeCommand implements BibleEditorCommand {
  final String fromThemeId;
  final String toThemeId;

  UpdateThemeCommand({required this.fromThemeId, required this.toThemeId});

  @override
  String get label => 'Cambiar tema';

  @override
  BibleDocument apply(BibleDocument doc) => doc.copyWith(themeId: toThemeId);

  @override
  BibleDocument undo(BibleDocument doc) => doc.copyWith(themeId: fromThemeId);
}

BibleDocument _updatePage(
  BibleDocument doc,
  String pageId,
  BiblePage Function(BiblePage) map,
) {
  return doc.copyWith(
    pages: doc.pages
        .map((p) => p.id == pageId ? map(p) : p)
        .toList(growable: false),
    updatedAt: DateTime.now().toUtc(),
  );
}

BibleDocument _mapBlock(
  BibleDocument doc,
  String pageId,
  String blockId,
  BibleBlock Function(BibleBlock) map,
) {
  return _updatePage(doc, pageId, (page) {
    return page.copyWith(
      blocks: page.blocks
          .map((b) => b.id == blockId ? map(b) : b)
          .toList(growable: false),
    );
  });
}
