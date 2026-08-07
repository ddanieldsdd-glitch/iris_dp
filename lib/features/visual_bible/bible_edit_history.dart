import 'visual_bible_model.dart';

/// Historial de ediciones de la Biblia (Cmd/Ctrl+Z / Shift+Z).
class BibleEditHistory {
  static const maxDepth = 40;

  final List<VisualBibleData> _undo = [];
  final List<VisualBibleData> _redo = [];
  bool _restoring = false;

  bool get canUndo => _undo.isNotEmpty;
  bool get canRedo => _redo.isNotEmpty;
  bool get isRestoring => _restoring;

  /// Guarda el estado actual antes de una mutación.
  void push(VisualBibleData current) {
    if (_restoring) return;
    _undo.add(current.copy());
    if (_undo.length > maxDepth) _undo.removeAt(0);
    _redo.clear();
  }

  VisualBibleData? undo(VisualBibleData current) {
    if (_undo.isEmpty) return null;
    _restoring = true;
    _redo.add(current.copy());
    final prev = _undo.removeLast();
    _restoring = false;
    return prev;
  }

  VisualBibleData? redo(VisualBibleData current) {
    if (_redo.isEmpty) return null;
    _restoring = true;
    _undo.add(current.copy());
    final next = _redo.removeLast();
    _restoring = false;
    return next;
  }

  void clear() {
    _undo.clear();
    _redo.clear();
  }
}
