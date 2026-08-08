import '../model/bible_document.dart';
import 'bible_editor_commands.dart';

/// Historial de comandos del editor v2 (documento completo).
class BibleDocumentHistory {
  static const maxDepth = 80;

  BibleDocument _current;
  final List<BibleEditorCommand> _undo = [];
  final List<BibleEditorCommand> _redo = [];

  BibleDocumentHistory(this._current);

  BibleDocument get current => _current;
  bool get canUndo => _undo.isNotEmpty;
  bool get canRedo => _redo.isNotEmpty;

  void replace(BibleDocument doc) {
    _current = doc;
    _undo.clear();
    _redo.clear();
  }

  BibleDocument execute(BibleEditorCommand command) {
    _current = command.apply(_current);
    _undo.add(command);
    if (_undo.length > maxDepth) _undo.removeAt(0);
    _redo.clear();
    return _current;
  }

  BibleDocument? undo() {
    if (_undo.isEmpty) return null;
    final cmd = _undo.removeLast();
    _current = cmd.undo(_current);
    _redo.add(cmd);
    return _current;
  }

  BibleDocument? redo() {
    if (_redo.isEmpty) return null;
    final cmd = _redo.removeLast();
    _current = cmd.apply(_current);
    _undo.add(cmd);
    return _current;
  }
}

/// Autosave con debounce.
class BibleDocumentAutosave {
  final Duration debounce;
  final Future<void> Function(BibleDocument doc) persist;

  DateTime? _lastScheduled;
  BibleDocument? _pending;
  bool _saving = false;

  BibleDocumentAutosave({
    required this.persist,
    this.debounce = const Duration(milliseconds: 800),
  });

  bool get isSaving => _saving;
  bool get hasPending => _pending != null;

  void schedule(BibleDocument doc) {
    _pending = doc;
    _lastScheduled = DateTime.now();
    Future<void>.delayed(debounce, () async {
      if (_pending == null) return;
      final scheduled = _lastScheduled;
      if (scheduled == null) return;
      if (DateTime.now().difference(scheduled) < debounce) return;
      final toSave = _pending;
      if (toSave == null) return;
      _pending = null;
      _saving = true;
      try {
        await persist(toSave);
      } finally {
        _saving = false;
      }
    });
  }

  Future<void> flush() async {
    final toSave = _pending;
    _pending = null;
    if (toSave == null) return;
    _saving = true;
    try {
      await persist(toSave);
    } finally {
      _saving = false;
    }
  }
}
