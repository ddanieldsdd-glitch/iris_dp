# IRIS DP — AI CONTEXT

## 1. PROJECT

* App Flutter de preproducción cinematográfica (guion, localizaciones, biblia visual, moodboard, equipo, export PDF, colaboración nube).
* Stack: Flutter 3.8+ / Dart, Riverpod, Drift+SQLite, Supabase Auth+Postgres+Storage, Cloudinary (media), Syncfusion/pdf, GitHub Actions release.
* Plataformas: macOS (principal), Windows, iPad/iOS (SideStore IPA). Sin Android en árbol.
* Estado: v1.0.19+16; nube opcional; Fase 3 piloto Camera cerrado (Format + Camera); rama `cursor/fase3-format-pilot` con cambios locales no commit.

## 2. ARCHITECTURE

UI (Screens/widgets en `lib/features/*`)
→ State (Riverpod Notifiers/Providers; `setState` OK para UI pura)
→ Services (`lib/core/sync`, `lib/core/cloud`, `lib/core/storage`, `lib/core/update`, feature services)
→ Repositories (parcial: VB, shoot_documents, floor_plan; muchas screens aún tocan DB)
→ Local DB / Cache (`AppDatabase` Drift schema **38**, SharedPreferences estilos/compositor)
→ Supabase (`cloud_projects`, snapshots, media metadata) + Cloudinary (bytes)

Reglas oficiales: `ARCHITECTURE.md` — `core` ↛ `features` (aún hay excepción en `app_database.dart`); features ↛ features salvo dominio justificado; UI ↛ Drift/Supabase directo (objetivo, no realidad total). Prioridad: estabilidad → mantenibilidad → features → UI.

## 3. DIRECTORY MAP

```
lib/
├── main.dart                 → bootstrap + gates
├── core/
│   ├── database/             → AppDatabase, tables, dao/
│   ├── sync/                 → SyncEngine, planes, bundle, media
│   ├── cloud/                → Supabase session/config, Cloudinary
│   ├── storage/              → carpeta cache local
│   ├── update/               → checker/installer desktop
│   └── theme|widgets|…       → infra UI transversal
├── features/                 → auth, projects, project_hub, scenes, shots,
│                               locations, visual_bible(+v2,export), equipment,
│                               optics_lab, storyboard, camera_plan, script_import,
│                               pdf_export, luka_export, onboarding, migration, …
└── shared/                   → auth, visual_bible (pilots resolve), annotations,
                                equipment, pdf_export, look_bible
supabase/migrations/          → SQL+RLS (001…010)
docs/                         → release, bible state, cloudinary (no es código)
test/                         → suite amplia
scripts/                      → build dmg/windows/ipad, register release
ARCHITECTURE.md · BACKLOG.md · README.md
```

## 4. DATA FLOW

Usuario → UI feature → Riverpod/state o servicio → Drift local (fuente offline)
→ sync manual (botón nube / `SyncFlowCoordinator`) → `SyncEngine`
→ metadatos proyecto (`ProjectSyncService` → `cloud_projects`)
→ contenido (`ProjectContentSyncService` + `ProjectContentBundle` → `cloud_project_snapshots`)
→ media (`MediaSyncService` / queue → Cloudinary; metadatos `media_assets`)
→ pull en otros dispositivos vía mismo plan (timestamps + elección usuario).

Sin credenciales Supabase → modo local puro.

## 5. SYNC

* **Qué:** metadatos de proyectos; snapshot JSON de contenido (escenas, planos, biblia legacy+v2 docs, moodboard, anotaciones, etc. bundle v4); cola de media; settings usuario (`UserSettingsSyncService`).
* **Dónde:** `lib/core/sync/` — orquestador `SyncEngine`; diff `SyncPlanBuilder`; apply `SyncPlanApplier`; contenido `project_content_*`; media `media_*`.
* **Cuándo:** sync **manual** (prepare → review plan → apply). No hay sync automático continuo confirmado en código.
* **Conflictos:** compara `syncUpdatedAt`/`updatedAt` local vs `updated_at` cloud → push/pull automático si un lado gana; empate/diff sin timestamp → `conflict` / `contentConflict` → usuario elige local|cloud|skip.
* **Límites:** requiere migración `007` snapshots; media depende Cloudinary dart-defines; plan de contenido es snapshot completo (no merge campo-a-campo); drift espurio de contenido filtrado en `SyncEngine`.

## 6. AUTH + SUPABASE

* Auth: email/password Supabase (`AuthScreen`); perfil auto en `profiles`.
* Tablas clave: `profiles`, `workspaces`, `workspace_members`, `cloud_projects`, `project_members`, `project_invitations`, `media_assets`, `cloud_project_snapshots`, `app_releases`, `user_settings`.
* RLS: activo; helpers SECURITY DEFINER anti-recursión (fixes 002–005); policies por ownership/membership.
* Storage: bucket `project-media` (RLS 008); bytes de imagen preferentemente Cloudinary; Supabase guarda paths/metadata.
* Usuario↔proyectos: DP owner ve workspace; director/viewer solo `project_members` / invitaciones por email.
* Seguridad: solo anon key en app; service role solo CI; nunca `.env` en commits; no importar `supabase_flutter` en features nuevas para lógica.

## 7. PLATFORMS

| Plataforma | Estado | Build | Distribución |
|---|---|---|---|
| Mac | Principal / estable | `scripts/build_macos_dmg.sh` | `.dmg` + GitHub Release; update in-app |
| Windows | Soportado | `scripts/build_windows.ps1` | `.zip` Release; update in-app |
| iPad/iOS | Funcional (biblia/moodboard v1) | `build_ipad.sh` / IPA unsigned | SideStore; TestFlight UNKNOWN |

## 8. CURRENT STATE

WORKING:

* Modo local offline + proyectos/escenas/planos/localizaciones
* Visual Bible UI clásica + moodboard + anotaciones compartidas
* Export PDF legacy + compositor híbrido
* Auth/sesión nube + invitaciones director
* Sync manual proyectos/contenido/media
* Equipo: routing cámara/lente + roles A-CAM/B-CAM
* Piloto Format: escritura canónica `formatData` + `FormatPilotResolve`
* Piloto Camera: escritura canónica `cameraData` + `CameraPilotResolve` (`captureResolution`)
* Release CI multiplataforma + checker actualizaciones
* Onboarding / storage relocation / connectivity gates

PARTIAL:

* Migración arquitectura (repos pocos; screens→DB aún frecuentes)
* `core`↛`features` (violación residual DB↔v2 codec)
* Bible engine v2 (código vivo; flag UI off)
* Dual-write legacy (presets aún escriben columnas Format)
* Unificación modos sensor Format ↔ Optics Lab PHFX
* Import Excel catálogo v1.1 (bloqueado a decisiones)
* QA iPad compositor con muchas imágenes
* Página PDF dedicada Localización (gap legacy)

BROKEN:

* (ninguno activo de export compositor citas vacías — resuelto)

UNKNOWN:

* Notarización Apple producción fuera de store
* Memoria/perf iPad compositor ~20 págs reales
* Paridad total Cloudinary en todos los builds locales de usuarios
* Cobertura RLS en proyecto Supabase desplegado del equipo

## 9. CRITICAL FILES

* `ARCHITECTURE.md` → reglas obligatorias agentes
* `BACKLOG.md` → deuda viva / pilots
* `lib/main.dart` → composition root / gates
* `lib/core/database/app_database.dart` → schema Drift 38 + migraciones
* `lib/core/sync/sync_engine.dart` → orquestación sync
* `lib/core/sync/sync_plan_builder.dart` → diff/conflictos
* `lib/core/sync/project_content_bundle.dart` → snapshot contenido
* `lib/core/sync/media_sync_service.dart` → media cloud
* `lib/core/cloud/cloud_providers.dart` → init Supabase
* `lib/features/auth/auth_screen.dart` → login
* `lib/features/projects/projects_screen.dart` → hub proyectos/sync UI entry
* `lib/features/project_hub/project_hub_router.dart` → navegación módulos
* `lib/features/visual_bible/visual_bible_screen.dart` → UI biblia canónica
* `lib/features/visual_bible/data/visual_bible_repository.dart` → persistencia VB
* `lib/features/visual_bible/visual_bible_pdf_service.dart` → PDF clásico
* `lib/features/visual_bible/export/builder/bible_export_composition_builder.dart` → compositor
* `lib/shared/visual_bible/format_pilot_resolve.dart` → lectura Format piloto
* `lib/shared/visual_bible/camera_pilot_resolve.dart` → lectura Camera piloto
* `lib/features/equipment/widgets/project_camera_roster_bar.dart` → roster A/B cam
* `supabase/migrations/001_initial_schema.sql` → auth/RLS base (+007 snapshots, 008/010 media)

## 10. DO NOT BREAK

* Contrato sync: timestamps + resolución manual de conflictos; no “auto-merge” silencioso de snapshots.
* Dual-read blob→legacy en Format/Camera (`*PilotResolve`); no borrar columnas legacy sin migrar todos los escritores.
* Visual Bible UI clásica / moodboard / compositor: cambios no destructivos; v2 no activar por defecto.
* Regla `core`↛`features` y aislamiento Supabase en `core/cloud|sync`.
* RLS + roles owner/director/viewer; no debilitar policies ni meter service role en cliente.

## 11. NEXT PRIORITIES

P0 Evitar stale dual-write: presets/`aspectRatio` y escritores externos documentados en `BACKLOG.md`.
P1 UI import catálogo en Equipo (JSON v1.7 Cámaras/Ópticas/Luces ya importables por API).
P2 Cascada arquitectura Equipo↔Biblia↔Format↔Lab (unificación modos Format↔Lab cerrada en slices).

## 12. HANDOFF

Si otro agente toma el proyecto ahora...
Proyecto en `/Users/danieldiaz/Documents/IRIS DP/iris_dp` (Flutter IRIS DP).
Hecho: Format+Camera piloto, compositor, moodboard, catálogo v1.7 Cámaras+Modos+Ópticas+Luces (`CatalogExcelImporter` + `docs/catalog/*`).
Pendiente: UI import Equipo, P3 unificación modos Format↔Lab, cascada arquitectura (fase aparte), dual-write presets.
Riesgo principal: romper lectura canónica blob/legacy o sync de snapshots al tocar biblia/equipo.
Siguiente acción: fase cascada de arquitectura (Equipo↔Biblia↔Lab) o UI import catálogo; unificación modos Format↔Lab cerrada.
Leer `ARCHITECTURE.md` + `BACKLOG.md` + `docs/catalog/README.md` antes de editar.
Mantener cambios mínimos y correr `flutter analyze` / tests afectados.
