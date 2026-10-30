/// Orden de una jornada por tramos de escena: los planos seguidos de una
/// misma escena forman un tramo, que se mueve entero. Código puro.
library;

/// Tramo: los bloques seguidos de una escena, en su orden.
class ShootTract {
  final int sceneId;
  final List<int> blockIds;

  const ShootTract(this.sceneId, this.blockIds);
}

/// Agrupa [blockIds] (en su orden) en tramos según la escena de cada uno.
List<ShootTract> groupShootTracts(
  List<int> blockIds,
  int Function(int blockId) sceneOf,
) {
  final tracts = <ShootTract>[];
  for (final id in blockIds) {
    final scene = sceneOf(id);
    if (tracts.isNotEmpty && tracts.last.sceneId == scene) {
      tracts.last.blockIds.add(id);
    } else {
      tracts.add(ShootTract(scene, [id]));
    }
  }
  return tracts;
}

/// Los bloques tras mover el tramo [from] al puesto [to] (ya el definitivo).
List<int> moveShootTract(List<ShootTract> tracts, int from, int to) {
  final next = [...tracts];
  next.insert(to, next.removeAt(from));
  return [
    for (final t in next) ...t.blockIds,
  ];
}

/// Los bloques en el orden del guion: por el puesto de su escena y, dentro
/// de ella, por el número de plano. El orden de partida desempata.
List<int> scriptOrderOf(
  List<int> blockIds, {
  required int Function(int blockId) scenePosition,
  required int Function(int blockId) shotNumber,
}) {
  final position = {for (final (i, id) in blockIds.indexed) id: i};
  return [...blockIds]..sort((a, b) {
    final scene = scenePosition(a).compareTo(scenePosition(b));
    if (scene != 0) return scene;
    final shot = shotNumber(a).compareTo(shotNumber(b));
    if (shot != 0) return shot;
    return position[a]!.compareTo(position[b]!);
  });
}
