/// Fab (la tienda de Epic, que incluye Quixel Megascans) desde IRIS
/// (F6.20 D1 y D4). Fab no tiene una API pública: IRIS abre la búsqueda en
/// el navegador; lo que se añade allí se descarga en Unreal con el plugin
/// Fab (Ventana → Fab) y IRIS lo recoge del proyecto (`FindFabAssets`).
abstract final class FabLinks {
  static const _host = 'www.fab.com';

  /// Búsqueda en Fab. Con [megascans], solo lo de Quixel.
  static Uri search(String query, {bool megascans = false}) => Uri.https(
    _host,
    '/search',
    {
      if (query.trim().isNotEmpty) 'q': query.trim(),
      if (megascans) 'seller': 'Quixel',
    },
  );

  /// Packs de partida para vestir un set: búsquedas en inglés, que es como
  /// están nombrados los assets en Fab.
  static const starterPacks = <(String, String)>[
    ('Salón', 'living room furniture'),
    ('Cocina', 'kitchen'),
    ('Dormitorio', 'bedroom'),
    ('Oficina', 'office'),
    ('Bar y restaurante', 'restaurant'),
    ('Calle', 'street props'),
    ('Coches', 'car'),
    ('Árboles', 'tree'),
    ('Rocas y terreno', 'rock'),
    ('Lámparas', 'lamp'),
    ('Puertas y ventanas', 'door window'),
    ('Superficies', 'surface'),
  ];
}
