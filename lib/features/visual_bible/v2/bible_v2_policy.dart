/// Política de evolución no destructiva del motor Biblia v2.
///
/// - El código legacy en `lib/features/visual_bible/` (excepto este árbol `v2/`)
///   no se elimina ni se renombra hasta cutover con parity tests.
/// - El flag [BibleEngineV2Flag] controla la UI nueva; default **off**.
/// - Migraciones Drift solo **añaden** tablas/columnas; no borran legacy.
/// - Desactivar el flag debe restaurar la experiencia Group→Section actual.
library;

/// Versión de schema del documento v2 (JSON embebido).
const int kBibleDocumentSchemaVersion = 1;

/// Motor legacy Group→Section.
const String kBibleEngineLegacy = 'legacy';

/// Motor modular Document→Page→Block.
const String kBibleEngineV2 = 'v2';

/// Prefijo de preferencias v2 (no usar para contenido estructural).
const String kBibleV2PrefsPrefix = 'iris_bible_v2_';
