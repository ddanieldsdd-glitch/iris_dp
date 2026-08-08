import '../model/bible_export_composition.dart';

typedef BibleExportCompositionMutation =
    BibleExportComposition Function(BibleExportComposition composition);

/// Historial de snapshots del montaje. Las anotaciones mantienen su propio
/// historial en [AnnotationCanvasController].
class BibleExportCompositionHistory {
  BibleExportCompositionHistory(this._current);

  static const int maxDepth = 80;

  BibleExportComposition _current;
  final List<BibleExportComposition> _undo = [];
  final List<BibleExportComposition> _redo = [];

  BibleExportComposition get current => _current;
  bool get canUndo => _undo.isNotEmpty;
  bool get canRedo => _redo.isNotEmpty;

  BibleExportComposition execute(BibleExportCompositionMutation mutation) {
    final next = mutation(_current);
    if (identical(next, _current)) return _current;
    _undo.add(_current);
    if (_undo.length > maxDepth) _undo.removeAt(0);
    _redo.clear();
    _current = next;
    return _current;
  }

  BibleExportComposition? undo() {
    if (_undo.isEmpty) return null;
    _redo.add(_current);
    _current = _undo.removeLast();
    return _current;
  }

  BibleExportComposition? redo() {
    if (_redo.isEmpty) return null;
    _undo.add(_current);
    _current = _redo.removeLast();
    return _current;
  }
}

BibleExportComposition reorderBibleExportPages(
  BibleExportComposition composition,
  int oldIndex,
  int newIndex,
) {
  if (oldIndex < 0 ||
      oldIndex >= composition.pages.length ||
      newIndex < 0 ||
      newIndex >= composition.pages.length) {
    return composition;
  }
  final pages = List<BibleExportPage>.from(composition.pages);
  final page = pages.removeAt(oldIndex);
  pages.insert(newIndex, page);
  return composition.copyWith(
    pages: [
      for (var index = 0; index < pages.length; index++)
        pages[index].copyWith(sortOrder: index),
    ],
    updatedAt: DateTime.now().toUtc(),
  );
}

BibleExportComposition replaceBibleExportPage(
  BibleExportComposition composition,
  BibleExportPage page,
) {
  if (composition.pageById(page.id) == null) return composition;
  return composition.copyWith(
    pages: [
      for (final current in composition.pages)
        if (current.id == page.id) page else current,
    ],
    updatedAt: DateTime.now().toUtc(),
  );
}

BibleExportComposition appendBibleExportPage(
  BibleExportComposition composition,
  BibleExportPage page,
) {
  return composition.copyWith(
    pages: [
      ...composition.pages,
      page.copyWith(sortOrder: composition.pages.length),
    ],
    updatedAt: DateTime.now().toUtc(),
  );
}
