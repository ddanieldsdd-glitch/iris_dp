import 'package:flutter/widgets.dart';

/// Algo que se puede añadir desde el 3D (ED.2): se elige y se suelta
/// tocando el suelo.
class Plan3dAddItem {
  final String group;
  final String label;
  final IconData icon;

  /// Lo añade en [at], en coordenadas de la planta.
  final Future<void> Function(Offset at) add;

  const Plan3dAddItem({
    required this.group,
    required this.label,
    required this.icon,
    required this.add,
  });
}

/// Lo que el 3D puede editar de la planta: añadir, duplicar, borrar y
/// deshacer. Cada acción falta si ahora no se puede hacer.
class Plan3dEditing {
  final List<Plan3dAddItem> items;
  final Future<void> Function()? duplicate;
  final Future<void> Function()? delete;
  final Future<void> Function()? undo;
  final Future<void> Function()? redo;

  /// Elige un asset de la biblioteca de Unreal (Fab, Megascans, el
  /// proyecto) y devuelve la pieza que se suelta con él.
  final Future<Plan3dAddItem?> Function()? pickAsset;

  const Plan3dEditing({
    this.items = const [],
    this.duplicate,
    this.delete,
    this.undo,
    this.redo,
    this.pickAsset,
  });

  /// El punto de la planta de un punto del suelo del visor ([x], [y] en
  /// metros, con y hacia el fondo, como manda el visor).
  static Offset canvasAt(double x, double y, double metersPerUnit) =>
      Offset(x / metersPerUnit, -y / metersPerUnit);

  /// Las mismas acciones, avisando con [done] al terminar cada una.
  Plan3dEditing then(VoidCallback done) {
    Future<void> Function()? wrap(Future<void> Function()? f) => f == null
        ? null
        : () async {
            await f();
            done();
          };
    Plan3dAddItem item(Plan3dAddItem i) => Plan3dAddItem(
      group: i.group,
      label: i.label,
      icon: i.icon,
      add: (at) async {
        await i.add(at);
        done();
      },
    );
    final pick = pickAsset;
    return Plan3dEditing(
      items: [for (final i in items) item(i)],
      pickAsset: pick == null
          ? null
          : () async {
              final picked = await pick();
              return picked == null ? null : item(picked);
            },
      duplicate: wrap(duplicate),
      delete: wrap(delete),
      undo: wrap(undo),
      redo: wrap(redo),
    );
  }
}
