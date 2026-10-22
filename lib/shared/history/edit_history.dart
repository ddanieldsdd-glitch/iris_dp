import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Un paso que se puede deshacer y rehacer.
class EditStep {
  /// Qué se hizo, para el aviso: «color del plano».
  final String label;
  final Future<void> Function() undo;
  final Future<void> Function() redo;

  const EditStep({required this.label, required this.undo, required this.redo});
}

/// Historial de cambios de una pantalla (⌘Z / ⇧⌘Z). Vive en memoria: se
/// vacía al salir de la pantalla.
class EditHistory extends ChangeNotifier {
  static const maxSteps = 100;

  final _done = <EditStep>[];
  final _undone = <EditStep>[];
  bool _busy = false;

  bool get canUndo => _done.isNotEmpty;
  bool get canRedo => _undone.isNotEmpty;

  /// Apunta un cambio ya hecho. Lo que hubiera por rehacer se pierde.
  void record(EditStep step) {
    // Deshacer y rehacer no se apuntan a sí mismos.
    if (_busy) return;
    _done.add(step);
    if (_done.length > maxSteps) _done.removeAt(0);
    _undone.clear();
    notifyListeners();
  }

  /// Deshace el último cambio; devuelve qué era, o nulo si no hay nada.
  Future<String?> undo() => _move(_done, _undone, (step) => step.undo());

  /// Rehace el último cambio deshecho.
  Future<String?> redo() => _move(_undone, _done, (step) => step.redo());

  Future<String?> _move(
    List<EditStep> from,
    List<EditStep> to,
    Future<void> Function(EditStep step) run,
  ) async {
    if (_busy || from.isEmpty) return null;
    _busy = true;
    final step = from.removeLast();
    try {
      await run(step);
      to.add(step);
      return step.label;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  void clear() {
    if (_done.isEmpty && _undone.isEmpty) return;
    _done.clear();
    _undone.clear();
    notifyListeners();
  }
}

/// Historial del guion técnico y de lo que se edita desde él (menús de
/// imagen). Uno para la app: la pantalla lo vacía al abrirse.
final editHistoryProvider = ChangeNotifierProvider<EditHistory>(
  (ref) => EditHistory(),
);
