import 'package:flutter/foundation.dart';

/// Lo que se arrastra desde la tira de planos a la planta (SV.3).
class PlanStripShot {
  final int shotId;
  const PlanStripShot(this.shotId);
}

/// Une la tira de planos de arriba con el editor del set (SV.3).
///
/// El editor dice qué cámara del set está seleccionada y a qué planos va;
/// la tira los resalta. Tocar un plano de la tira con una cámara
/// seleccionada la vincula o la desvincula; «+ cámara» en un plano sin
/// cámara la crea ya vinculada.
class PlanStripLink extends ChangeNotifier {
  /// Letra de la cámara del set seleccionada, o nula.
  String? camera;

  /// Planos a los que va esa cámara.
  Set<int> linked = const {};

  Future<void> Function(int shotId)? _onToggle;
  Future<void> Function(int shotId)? _onAddCamera;
  Object? _owner;

  /// El editor abierto se apunta; el anterior deja de recibir.
  void attach(
    Object owner, {
    required Future<void> Function(int shotId) onToggle,
    required Future<void> Function(int shotId) onAddCamera,
  }) {
    _owner = owner;
    _onToggle = onToggle;
    _onAddCamera = onAddCamera;
  }

  void detach(Object owner) {
    if (_owner != owner) return;
    _owner = null;
    _onToggle = null;
    _onAddCamera = null;
    show(null, const {});
  }

  /// Hay un editor de set que admite cámaras nuevas desde la tira.
  bool get canAddCamera => _onAddCamera != null;

  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void show(String? camera, Set<int> linked) {
    if (_disposed) return;
    if (this.camera == camera && setEquals(this.linked, linked)) return;
    this.camera = camera;
    this.linked = linked;
    notifyListeners();
  }

  Future<void> toggle(int shotId) async => _onToggle?.call(shotId);

  Future<void> addCamera(int shotId) async => _onAddCamera?.call(shotId);
}
