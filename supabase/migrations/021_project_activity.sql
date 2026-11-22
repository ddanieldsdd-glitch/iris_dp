-- Autoría: quién cambió qué en un proyecto compartido (P1, prueba 2).
-- Ejecutar en Supabase SQL Editor después de 020.
--
-- · Cada vez que un equipo sube un proyecto, la app anota qué cambió desde
--   la última sincronización (un plano, su planta, una escena, un set…),
--   quién y cuándo: una fila por cosa cambiada.
-- · Lo ven el dueño del proyecto y quienes están en él; lo escribe solo
--   quien puede editarlo, y siempre a su nombre.
-- · iris_project_activity() da la lista para la pantalla «Actividad» e
--   iris_last_changes() el último cambio de cada cosa, con nombre y papel.
--
-- No borra nada y se puede ejecutar más de una vez.

CREATE TABLE IF NOT EXISTS public.project_activity (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  project_id UUID NOT NULL REFERENCES public.cloud_projects(id) ON DELETE CASCADE,
  user_id UUID NOT NULL DEFAULT auth.uid()
    REFERENCES auth.users(id) ON DELETE CASCADE,
  at TIMESTAMPTZ NOT NULL DEFAULT now(),
  device TEXT CHECK (char_length(device) <= 80),
  -- shots, scenes, locationBasePlans… o un bloque (biblia, equipo…).
  collection TEXT NOT NULL CHECK (char_length(collection) <= 60),
  uid TEXT CHECK (char_length(uid) <= 80),
  label TEXT CHECK (char_length(label) <= 200),
  action TEXT NOT NULL CHECK (action IN ('added', 'edited', 'removed')),
  -- Qué partes: «planta», «lente», «descripción»…
  fields TEXT[] CHECK (cardinality(fields) <= 20)
);

CREATE INDEX IF NOT EXISTS project_activity_project_at_idx
  ON public.project_activity (project_id, at DESC);
CREATE INDEX IF NOT EXISTS project_activity_thing_idx
  ON public.project_activity (project_id, collection, uid, at DESC);

ALTER TABLE public.project_activity ENABLE ROW LEVEL SECURITY;

-- Puede ver el proyecto: es suyo, está en él, o es el administrador.
CREATE OR REPLACE FUNCTION public.iris_can_see_project(p uuid)
RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public
AS $$
  SELECT p IN (SELECT public.owned_workspace_project_ids())
      OR p IN (SELECT public.member_project_ids())
      OR public.is_app_admin();
$$;

REVOKE ALL ON FUNCTION public.iris_can_see_project(uuid) FROM public, anon;
GRANT EXECUTE ON FUNCTION public.iris_can_see_project(uuid) TO authenticated;

DROP POLICY IF EXISTS project_activity_select ON public.project_activity;
CREATE POLICY project_activity_select ON public.project_activity
  FOR SELECT TO authenticated
  USING (public.iris_can_see_project(project_id));

DROP POLICY IF EXISTS project_activity_insert ON public.project_activity;
CREATE POLICY project_activity_insert ON public.project_activity
  FOR INSERT TO authenticated
  WITH CHECK (
    user_id = auth.uid()
    AND public.app_access_active()
    AND (project_id IN (SELECT public.owned_workspace_project_ids())
         OR project_id IN (SELECT public.editable_project_ids()))
  );
-- Sin UPDATE ni DELETE: lo anotado no se cambia (se va con el proyecto).

-- Quién es cada cual en el proyecto: nombre y papel (sin fila: el dueño).
CREATE OR REPLACE FUNCTION public.iris_project_activity(
  p_project uuid,
  p_limit int DEFAULT 200,
  p_before timestamptz DEFAULT NULL
)
RETURNS TABLE (
  id bigint, at timestamptz, user_id uuid, name text, role text,
  device text, collection text, uid text, label text, action text,
  fields text[]
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT public.iris_can_see_project(p_project) THEN
    RAISE EXCEPTION 'IRIS_ACTIVITY_FORBIDDEN';
  END IF;
  RETURN QUERY
  SELECT a.id, a.at, a.user_id, p.display_name, m.role, a.device,
         a.collection, a.uid, a.label, a.action, a.fields
  FROM project_activity a
  LEFT JOIN profiles p ON p.id = a.user_id
  LEFT JOIN project_members m
    ON m.project_id = a.project_id AND m.user_id = a.user_id
  WHERE a.project_id = p_project
    AND (p_before IS NULL OR a.at < p_before)
  ORDER BY a.at DESC, a.id DESC
  LIMIT LEAST(GREATEST(COALESCE(p_limit, 200), 1), 500);
END;
$$;

REVOKE ALL ON FUNCTION public.iris_project_activity(uuid, int, timestamptz) FROM public, anon;
GRANT EXECUTE ON FUNCTION public.iris_project_activity(uuid, int, timestamptz) TO authenticated;

-- El último cambio de cada cosa del proyecto.
CREATE OR REPLACE FUNCTION public.iris_last_changes(p_project uuid)
RETURNS TABLE (
  at timestamptz, user_id uuid, name text, role text, device text,
  collection text, uid text, label text, action text, fields text[]
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT public.iris_can_see_project(p_project) THEN
    RAISE EXCEPTION 'IRIS_ACTIVITY_FORBIDDEN';
  END IF;
  RETURN QUERY
  SELECT DISTINCT ON (a.collection, a.uid)
         a.at, a.user_id, p.display_name, m.role, a.device,
         a.collection, a.uid, a.label, a.action, a.fields
  FROM project_activity a
  LEFT JOIN profiles p ON p.id = a.user_id
  LEFT JOIN project_members m
    ON m.project_id = a.project_id AND m.user_id = a.user_id
  WHERE a.project_id = p_project AND a.uid IS NOT NULL
  ORDER BY a.collection, a.uid, a.at DESC, a.id DESC;
END;
$$;

REVOKE ALL ON FUNCTION public.iris_last_changes(uuid) FROM public, anon;
GRANT EXECUTE ON FUNCTION public.iris_last_changes(uuid) TO authenticated;

-- ─── Comprobar ─────────────────────────────────────────────────────────────
-- Debe devolver 0 filas de actividad y 3 funciones.
SELECT
  (SELECT count(*) FROM public.project_activity) AS filas,
  (SELECT count(*) FROM pg_proc WHERE proname IN (
     'iris_can_see_project', 'iris_project_activity', 'iris_last_changes'))
    AS funciones;
