/// Niveles de acceso para colaboración en equipo (Supabase — iteración futura).
enum ProjectAccessLevel {
  /// DP — acceso total.
  owner,

  /// Gaffer, AD — edición de planos y planta.
  editor,

  /// Producción — lectura y descarga de PDFs.
  viewer,
}

/// Notas de implementación futura (Fase 4 — base documentada).
///
/// Flujo previsto:
/// 1. El DP genera enlace: projectId + token + nivel (viewer/editor).
/// 2. El invitado abre la app e introduce el código.
/// 3. Sync vía Supabase Realtime cuando el equipo lo solicite.
///
/// Por ahora la colaboración se apoya en export PDF + GoodNotes.
