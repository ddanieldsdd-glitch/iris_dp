# Supabase — IRIS DP Cloud

## Setup

1. Crea un proyecto en [supabase.com](https://supabase.com)
2. Ejecuta las migraciones en orden (SQL Editor): `001` … `016_access_admin.sql`. La `017` solo cuando quieras recortar el historial (ver abajo)
3. Verifica el bucket Storage `project-media` (privado, RLS activo — la migración 008 crea políticas) y `avatars` (público, cada usuario escribe solo en su carpeta — migración 012)
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

## Perfiles y espacio usado (012)

- `profiles.display_name` y `profiles.avatar_url` se editan desde el avatar de la pantalla de proyectos → «Editar perfil». La foto va a `avatars/{user_id}/avatar.jpg` (JPEG 512×512).
- Cada persona ve los perfiles de quien comparte con ella workspace o proyecto (`can_see_profile`). `workspace_member_profiles(ws)` devuelve el equipo de un workspace.
- `iris_storage_usage()` devuelve el tamaño de la base, los archivos de Storage por bucket y los bytes de Cloudinary registrados en `media_assets` (estimación), para Ajustes → «Espacio en la nube».

## Acceso, administrador e invitados (016)

- `app_access`: una fila por cuenta con `role` (`admin` | `guest`), `status` (`pending` | `active` | `suspended`), `message` y `storage_limit_bytes`. Las cuentas que existían al aplicar la migración quedan activas; la más antigua pasa a `admin` (la consulta del final del archivo lo enseña: si no es la buena, cámbialo ahí mismo). Las cuentas nuevas nacen `pending`.
- `app_state`: `maintenance`, `message` y `min_build` para toda la app.
- La app pregunta `iris_access_check()` al abrir, al volver a ella y cada hora. Con el acceso cerrado no se abre (no borra nada del equipo). Sin conexión vale la última respuesta 7 días; al administrador, siempre.
- El administrador **lee** proyectos, contenido e imágenes de todas las cuentas (reglas `*_admin_select`), pero nunca escribe en ellos.
- Una cuenta que no está activa (o un invitado durante el mantenimiento) no puede escribir en la nube: reglas restrictivas `*_active_ins/upd/del`. Esto también corta la nube a versiones antiguas de la app que no tienen la pantalla de cierre.
- Cupo: si el espacio de trabajo de una cuenta pasa de `storage_limit_bytes`, el contenido de sus proyectos no puede crecer (`IRIS_QUOTA_EXCEEDED`). Las imágenes de Cloudinary cuentan en la medida pero no se pueden frenar desde el servidor.
- Funciones del administrador: `iris_admin_accounts()`, `iris_admin_set_access(...)`, `iris_admin_set_state(...)`, `iris_admin_projects()`. Todo esto se maneja en la app desde Ajustes → «Invitados».

## Historial más corto (017)

Baja el historial de 20 a 8 versiones por proyecto y **borra** las que sobran. Ejecutar solo después de ver en Ajustes → «Invitados» cuánto ocupa el historial.
