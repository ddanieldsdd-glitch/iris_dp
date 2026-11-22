-- Acceso por cuenta, administrador, mantenimiento y cupo de espacio.
-- Ejecutar en Supabase SQL Editor después de 015.
--
-- · Cada cuenta tiene una fila en app_access: rol (admin | guest) y estado
--   (pending | active | suspended). Las cuentas que ya existen quedan activas;
--   las nuevas nacen pendientes hasta que el administrador las aprueba.
-- · El administrador lee los proyectos de todos (nunca los escribe).
-- · Una cuenta que no está activa sigue pudiendo leer lo suyo (la app no borra
--   nada de su equipo), pero no puede subir ni cambiar nada en la nube.
-- · app_state: mantenimiento y versión mínima para toda la app.
-- · Cupo: si el espacio de trabajo de una cuenta supera su límite, la nube
--   rechaza que su contenido crezca (error IRIS_QUOTA_EXCEEDED).
--
-- Es compatible con versiones anteriores de la app: para las cuentas activas
-- nada cambia.

-- ─── Tablas ────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.app_access (
  user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  role TEXT NOT NULL DEFAULT 'guest' CHECK (role IN ('admin', 'guest')),
  status TEXT NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending', 'active', 'suspended')),
  -- Lo que ve la persona cuando su acceso está cerrado.
  message TEXT,
  -- Tope de espacio de su espacio de trabajo. Nulo: sin tope.
  storage_limit_bytes BIGINT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.app_state (
  id INT PRIMARY KEY DEFAULT 1 CHECK (id = 1),
  maintenance BOOLEAN NOT NULL DEFAULT false,
  message TEXT,
  -- Compilación mínima con la que se puede entrar. 0: cualquiera.
  min_build INT NOT NULL DEFAULT 0,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

INSERT INTO public.app_state (id) VALUES (1) ON CONFLICT (id) DO NOTHING;

DROP TRIGGER IF EXISTS app_access_updated ON public.app_access;
CREATE TRIGGER app_access_updated BEFORE UPDATE ON public.app_access
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();
DROP TRIGGER IF EXISTS app_state_updated ON public.app_state;
CREATE TRIGGER app_state_updated BEFORE UPDATE ON public.app_state
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- Las cuentas que ya existen entran activas.
INSERT INTO public.app_access (user_id, role, status)
SELECT id, 'guest', 'active' FROM auth.users
ON CONFLICT (user_id) DO NOTHING;

-- Administrador: si aún no hay ninguno, la cuenta más antigua.
-- Comprobar con la consulta del final y cambiarlo a mano si no es la buena.
UPDATE public.app_access SET role = 'admin', status = 'active'
WHERE user_id = (SELECT id FROM auth.users ORDER BY created_at LIMIT 1)
  AND NOT EXISTS (SELECT 1 FROM public.app_access WHERE role = 'admin');

-- Cuentas nuevas: pendientes.
CREATE OR REPLACE FUNCTION public.handle_new_user_access()
RETURNS TRIGGER
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  INSERT INTO public.app_access (user_id, role, status)
  VALUES (NEW.id, 'guest', 'pending')
  ON CONFLICT (user_id) DO NOTHING;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_auth_user_created_access ON auth.users;
CREATE TRIGGER on_auth_user_created_access
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user_access();

-- ─── Funciones de permiso ──────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.is_app_admin()
RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.app_access
    WHERE user_id = auth.uid() AND role = 'admin' AND status = 'active'
  );
$$;

-- Puede escribir en la nube: cuenta activa y, si hay mantenimiento, admin.
CREATE OR REPLACE FUNCTION public.app_access_active()
RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.app_access a
    WHERE a.user_id = auth.uid() AND a.status = 'active'
      AND (a.role = 'admin'
           OR NOT COALESCE((SELECT maintenance FROM public.app_state WHERE id = 1), false))
  );
$$;

GRANT EXECUTE ON FUNCTION public.is_app_admin() TO authenticated;
GRANT EXECUTE ON FUNCTION public.app_access_active() TO authenticated;

ALTER TABLE public.app_access ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.app_state ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS app_access_select ON public.app_access;
CREATE POLICY app_access_select ON public.app_access
  FOR SELECT TO authenticated
  USING (user_id = auth.uid() OR public.is_app_admin());
-- Sin políticas de escritura: se cambia con iris_admin_set_access().

DROP POLICY IF EXISTS app_state_select ON public.app_state;
CREATE POLICY app_state_select ON public.app_state
  FOR SELECT TO authenticated USING (true);


-- ─── Lectura del administrador (se suma a las reglas que ya hay) ───────────

DROP POLICY IF EXISTS workspaces_admin_select ON public.workspaces;
CREATE POLICY workspaces_admin_select ON public.workspaces
  FOR SELECT TO authenticated USING (public.is_app_admin());

DROP POLICY IF EXISTS projects_admin_select ON public.cloud_projects;
CREATE POLICY projects_admin_select ON public.cloud_projects
  FOR SELECT TO authenticated USING (public.is_app_admin());

DROP POLICY IF EXISTS snapshot_admin_select ON public.cloud_project_snapshots;
CREATE POLICY snapshot_admin_select ON public.cloud_project_snapshots
  FOR SELECT TO authenticated USING (public.is_app_admin());

DROP POLICY IF EXISTS media_admin_select ON public.media_assets;
CREATE POLICY media_admin_select ON public.media_assets
  FOR SELECT TO authenticated USING (public.is_app_admin());

DROP POLICY IF EXISTS profiles_admin_select ON public.profiles;
CREATE POLICY profiles_admin_select ON public.profiles
  FOR SELECT TO authenticated USING (public.is_app_admin());

DROP POLICY IF EXISTS project_media_admin_select ON storage.objects;
CREATE POLICY project_media_admin_select ON storage.objects
  FOR SELECT TO authenticated
  USING (bucket_id = 'project-media' AND public.is_app_admin());

-- ─── Escritura solo con la cuenta activa (reglas restrictivas) ─────────────
-- Se suman con AND a las que ya existen. La lectura no cambia.

DO $$
DECLARE
  t text;
BEGIN
  FOREACH t IN ARRAY ARRAY[
    'cloud_projects', 'cloud_project_snapshots', 'media_assets',
    'project_invitations', 'project_members', 'plan_library'
  ] LOOP
    IF to_regclass('public.' || t) IS NULL THEN CONTINUE; END IF;
    EXECUTE format('DROP POLICY IF EXISTS %I ON public.%I', t || '_active_ins', t);
    EXECUTE format('DROP POLICY IF EXISTS %I ON public.%I', t || '_active_upd', t);
    EXECUTE format('DROP POLICY IF EXISTS %I ON public.%I', t || '_active_del', t);
    EXECUTE format(
      'CREATE POLICY %I ON public.%I AS RESTRICTIVE FOR INSERT TO authenticated
         WITH CHECK (public.app_access_active())', t || '_active_ins', t);
    EXECUTE format(
      'CREATE POLICY %I ON public.%I AS RESTRICTIVE FOR UPDATE TO authenticated
         USING (public.app_access_active()) WITH CHECK (public.app_access_active())',
      t || '_active_upd', t);
    EXECUTE format(
      'CREATE POLICY %I ON public.%I AS RESTRICTIVE FOR DELETE TO authenticated
         USING (public.app_access_active())', t || '_active_del', t);
  END LOOP;
END $$;

DROP POLICY IF EXISTS project_media_active_ins ON storage.objects;
CREATE POLICY project_media_active_ins ON storage.objects
  AS RESTRICTIVE FOR INSERT TO authenticated
  WITH CHECK (bucket_id <> 'project-media' OR public.app_access_active());

DROP POLICY IF EXISTS project_media_active_upd ON storage.objects;
CREATE POLICY project_media_active_upd ON storage.objects
  AS RESTRICTIVE FOR UPDATE TO authenticated
  USING (bucket_id <> 'project-media' OR public.app_access_active());

DROP POLICY IF EXISTS project_media_active_del ON storage.objects;
CREATE POLICY project_media_active_del ON storage.objects
  AS RESTRICTIVE FOR DELETE TO authenticated
  USING (bucket_id <> 'project-media' OR public.app_access_active());

-- ─── Espacio por espacio de trabajo ────────────────────────────────────────

-- Bytes que ocupa un espacio de trabajo: contenido, historial e imágenes.
CREATE OR REPLACE FUNCTION public.workspace_usage_bytes(ws uuid)
RETURNS TABLE (content_bytes bigint, history_bytes bigint, media_bytes bigint)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public
AS $$
  SELECT
    COALESCE((SELECT sum(pg_column_size(s.content))::bigint
      FROM cloud_project_snapshots s
      JOIN cloud_projects p ON p.id = s.project_id
      WHERE p.workspace_id = ws), 0),
    COALESCE((SELECT sum(pg_column_size(h.content))::bigint
      FROM cloud_project_snapshot_history h
      JOIN cloud_projects p ON p.id = h.project_id
      WHERE p.workspace_id = ws), 0),
    COALESCE((SELECT sum(COALESCE(m.bytes_stored, m.bytes_original, 0))::bigint
      FROM media_assets m
      JOIN cloud_projects p ON p.id = m.project_id
      WHERE p.workspace_id = ws), 0);
$$;

REVOKE ALL ON FUNCTION public.workspace_usage_bytes(uuid) FROM public, anon, authenticated;

-- Lo que la app pregunta al abrir: acceso, mantenimiento, versión mínima y,
-- si la cuenta tiene tope, lo que ocupa.
CREATE OR REPLACE FUNCTION public.iris_access_check()
RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  a app_access%ROWTYPE;
  s app_state%ROWTYPE;
  ws uuid;
  used bigint;
BEGIN
  SELECT * INTO a FROM app_access WHERE user_id = auth.uid();
  SELECT * INTO s FROM app_state WHERE id = 1;
  IF a.storage_limit_bytes IS NOT NULL THEN
    SELECT w.id INTO ws FROM workspaces w
    WHERE w.owner_id = auth.uid() ORDER BY w.created_at LIMIT 1;
    IF ws IS NOT NULL THEN
      SELECT u.content_bytes + u.history_bytes + u.media_bytes INTO used
      FROM public.workspace_usage_bytes(ws) u;
    END IF;
  END IF;
  RETURN jsonb_build_object(
    'status', COALESCE(a.status, 'pending'),
    'role', COALESCE(a.role, 'guest'),
    'message', a.message,
    'storage_limit_bytes', a.storage_limit_bytes,
    'used_bytes', used,
    'maintenance', COALESCE(s.maintenance, false),
    'maintenance_message', s.message,
    'min_build', COALESCE(s.min_build, 0),
    'server_time', now()
  );
END;
$$;

REVOKE ALL ON FUNCTION public.iris_access_check() FROM public, anon;
GRANT EXECUTE ON FUNCTION public.iris_access_check() TO authenticated;

-- Cupo: el contenido de un proyecto no puede crecer si su espacio de trabajo
-- ya pasa del tope de su dueño. Reducirlo siempre se puede.
CREATE OR REPLACE FUNCTION public.enforce_workspace_quota()
RETURNS TRIGGER
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  lim bigint;
  ws uuid;
  used bigint;
  new_size bigint := pg_column_size(NEW.content);
  old_size bigint := 0;
BEGIN
  IF TG_OP = 'UPDATE' THEN
    old_size := pg_column_size(OLD.content);
    IF new_size <= old_size THEN RETURN NEW; END IF;
  END IF;

  SELECT p.workspace_id, a.storage_limit_bytes INTO ws, lim
  FROM cloud_projects p
  JOIN workspaces w ON w.id = p.workspace_id
  LEFT JOIN app_access a ON a.user_id = w.owner_id
  WHERE p.id = NEW.project_id;

  IF lim IS NULL THEN RETURN NEW; END IF;

  SELECT u.content_bytes + u.history_bytes + u.media_bytes INTO used
  FROM public.workspace_usage_bytes(ws) u;

  IF used - old_size + new_size > lim THEN
    RAISE EXCEPTION 'IRIS_QUOTA_EXCEEDED'
      USING DETAIL = format('usado %s de %s bytes', used, lim),
            HINT = 'Se ha llegado al límite de espacio de esta cuenta.';
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS cloud_project_snapshots_quota ON public.cloud_project_snapshots;
CREATE TRIGGER cloud_project_snapshots_quota
  BEFORE INSERT OR UPDATE OF content ON public.cloud_project_snapshots
  FOR EACH ROW EXECUTE FUNCTION public.enforce_workspace_quota();

-- ─── Funciones del administrador ───────────────────────────────────────────

-- Cuentas con su estado y lo que ocupan.
CREATE OR REPLACE FUNCTION public.iris_admin_accounts()
RETURNS TABLE (
  user_id uuid,
  email text,
  display_name text,
  role text,
  status text,
  message text,
  storage_limit_bytes bigint,
  created_at timestamptz,
  last_sign_in_at timestamptz,
  workspace_id uuid,
  project_count bigint,
  content_bytes bigint,
  history_bytes bigint,
  media_bytes bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT public.is_app_admin() THEN
    RAISE EXCEPTION 'Solo el administrador';
  END IF;
  RETURN QUERY
  SELECT
    u.id, u.email::text, p.display_name, a.role, a.status, a.message,
    a.storage_limit_bytes, u.created_at, u.last_sign_in_at,
    w.id,
    (SELECT count(*) FROM cloud_projects cp WHERE cp.workspace_id = w.id),
    COALESCE(us.content_bytes, 0), COALESCE(us.history_bytes, 0),
    COALESCE(us.media_bytes, 0)
  FROM auth.users u
  JOIN app_access a ON a.user_id = u.id
  LEFT JOIN profiles p ON p.id = u.id
  LEFT JOIN LATERAL (
    SELECT ws.id FROM workspaces ws WHERE ws.owner_id = u.id
    ORDER BY ws.created_at LIMIT 1
  ) w ON true
  LEFT JOIN LATERAL public.workspace_usage_bytes(w.id) us ON w.id IS NOT NULL
  ORDER BY (a.role = 'admin') DESC, u.created_at;
END;
$$;

-- Cambia el acceso de una cuenta. Nulo deja ese dato como está; el tope se
-- quita con p_clear_limit.
CREATE OR REPLACE FUNCTION public.iris_admin_set_access(
  p_user uuid,
  p_status text DEFAULT NULL,
  p_message text DEFAULT NULL,
  p_limit bigint DEFAULT NULL,
  p_clear_limit boolean DEFAULT false
)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT public.is_app_admin() THEN
    RAISE EXCEPTION 'Solo el administrador';
  END IF;
  IF p_user = auth.uid() AND p_status IS NOT NULL AND p_status <> 'active' THEN
    RAISE EXCEPTION 'El administrador no puede cerrarse el acceso a sí mismo';
  END IF;
  UPDATE app_access SET
    status = COALESCE(p_status, status),
    message = CASE WHEN p_message IS NULL THEN message
                   ELSE NULLIF(trim(p_message), '') END,
    storage_limit_bytes = CASE WHEN p_clear_limit THEN NULL
                               ELSE COALESCE(p_limit, storage_limit_bytes) END
  WHERE user_id = p_user;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Cuenta no encontrada';
  END IF;
END;
$$;

CREATE OR REPLACE FUNCTION public.iris_admin_set_state(
  p_maintenance boolean,
  p_message text DEFAULT NULL,
  p_min_build int DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT public.is_app_admin() THEN
    RAISE EXCEPTION 'Solo el administrador';
  END IF;
  UPDATE app_state SET
    maintenance = p_maintenance,
    message = NULLIF(trim(COALESCE(p_message, '')), ''),
    min_build = COALESCE(p_min_build, min_build)
  WHERE id = 1;
END;
$$;

-- Proyectos de las demás cuentas, para verlos en solo lectura.
CREATE OR REPLACE FUNCTION public.iris_admin_projects()
RETURNS TABLE (
  project_id uuid,
  name text,
  director_display text,
  status text,
  icon_code int,
  owner_id uuid,
  owner_name text,
  updated_at timestamptz,
  content_updated_at timestamptz,
  scene_count int,
  shot_count int
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT public.is_app_admin() THEN
    RAISE EXCEPTION 'Solo el administrador';
  END IF;
  RETURN QUERY
  SELECT cp.id, cp.name, cp.director_display, cp.status, cp.icon_code,
    w.owner_id, COALESCE(p.display_name, ''), cp.updated_at,
    s.updated_at, COALESCE(s.scene_count, 0), COALESCE(s.shot_count, 0)
  FROM cloud_projects cp
  JOIN workspaces w ON w.id = cp.workspace_id
  LEFT JOIN profiles p ON p.id = w.owner_id
  LEFT JOIN cloud_project_snapshots s ON s.project_id = cp.id
  WHERE w.owner_id <> auth.uid()
  ORDER BY p.display_name, cp.sort_order, cp.name;
END;
$$;

REVOKE ALL ON FUNCTION public.iris_admin_accounts() FROM public, anon;
REVOKE ALL ON FUNCTION public.iris_admin_set_access(uuid, text, text, bigint, boolean) FROM public, anon;
REVOKE ALL ON FUNCTION public.iris_admin_set_state(boolean, text, int) FROM public, anon;
REVOKE ALL ON FUNCTION public.iris_admin_projects() FROM public, anon;
GRANT EXECUTE ON FUNCTION public.iris_admin_accounts() TO authenticated;
GRANT EXECUTE ON FUNCTION public.iris_admin_set_access(uuid, text, text, bigint, boolean) TO authenticated;
GRANT EXECUTE ON FUNCTION public.iris_admin_set_state(boolean, text, int) TO authenticated;
GRANT EXECUTE ON FUNCTION public.iris_admin_projects() TO authenticated;

-- ─── Comprobar ─────────────────────────────────────────────────────────────
-- Debe salir tu cuenta como admin. Si no, cambiarlo con:
--   UPDATE app_access SET role = 'guest' WHERE role = 'admin';
--   UPDATE app_access SET role = 'admin', status = 'active'
--   WHERE user_id = (SELECT id FROM auth.users WHERE email = 'tu correo');
SELECT u.email, a.role, a.status
FROM public.app_access a JOIN auth.users u ON u.id = a.user_id
ORDER BY (a.role = 'admin') DESC, u.created_at;
