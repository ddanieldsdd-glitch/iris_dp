# Supabase — IRIS DP Cloud

## Setup

1. Crea un proyecto en [supabase.com](https://supabase.com)
2. Ejecuta las migraciones en orden (SQL Editor): `001` … `008_storage_project_media_rls.sql`
3. Verifica el bucket Storage `project-media` (privado, RLS activo — la migración 008 crea políticas)
4. Copia URL y anon key a las variables de entorno de la app

## Variables de entorno (build / run)

```bash
flutter run -d macos \
  --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=YOUR_ANON_KEY
```

Sin estas variables la app funciona en **modo local** (sin cuenta ni sync).

## Roles

| Rol | Tabla | Permisos |
|-----|-------|----------|
| DP owner | `workspace_members.role = owner` | Ve todos los proyectos del workspace |
| Director | `project_members.role = director` | Solo proyectos asignados |
| Viewer | `project_members.role = viewer` | Solo lectura en proyectos asignados |

## Invitaciones

El DP invita por email desde la app → fila en `project_invitations` → el director se registra y acepta.
