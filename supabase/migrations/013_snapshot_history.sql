-- Historial del contenido de cada proyecto y hora del servidor.
-- Cada versión es una copia del JSON: se guarda como mucho una cada 30
-- minutos (las subidas llegan segundos después de cada edición), salvo si el
-- proyecto pierde planos, y se conservan las 20 últimas por proyecto.

-- La columna es de la migración 011; el disparador la necesita.
ALTER TABLE cloud_project_snapshots
  ADD COLUMN IF NOT EXISTS updated_device TEXT;

CREATE TABLE IF NOT EXISTS cloud_project_snapshot_history (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  project_id UUID NOT NULL REFERENCES cloud_projects(id) ON DELETE CASCADE,
  content JSONB NOT NULL,
  content_hash TEXT,
  scene_count INT NOT NULL DEFAULT 0,
  shot_count INT NOT NULL DEFAULT 0,
  updated_device TEXT,
  saved_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_snapshot_history_project
  ON cloud_project_snapshot_history(project_id, saved_at DESC);

ALTER TABLE cloud_project_snapshot_history ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS snapshot_history_select ON cloud_project_snapshot_history;
CREATE POLICY snapshot_history_select ON cloud_project_snapshot_history
  FOR SELECT USING (
    project_id IN (SELECT public.owned_workspace_project_ids())
    OR project_id IN (SELECT public.member_project_ids())
  );

CREATE OR REPLACE FUNCTION public.archive_project_snapshot()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF OLD.content_hash IS NOT DISTINCT FROM NEW.content_hash THEN
    RETURN NEW;
  END IF;
  IF current_setting('iris.force_history', true) = '1'
     OR NEW.shot_count < OLD.shot_count
     OR NOT EXISTS (
       SELECT 1 FROM cloud_project_snapshot_history
       WHERE project_id = OLD.project_id
         AND saved_at > now() - interval '30 minutes'
     )
  THEN
    INSERT INTO cloud_project_snapshot_history
      (project_id, content, content_hash, scene_count, shot_count, updated_device)
    VALUES
      (OLD.project_id, OLD.content, OLD.content_hash, OLD.scene_count,
       OLD.shot_count, OLD.updated_device);
    DELETE FROM cloud_project_snapshot_history
    WHERE project_id = OLD.project_id
      AND id NOT IN (
        SELECT id FROM cloud_project_snapshot_history
        WHERE project_id = OLD.project_id
        ORDER BY saved_at DESC, id DESC
        LIMIT 20
      );
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS cloud_project_snapshots_archive ON cloud_project_snapshots;
CREATE TRIGGER cloud_project_snapshots_archive
  BEFORE UPDATE ON cloud_project_snapshots
  FOR EACH ROW EXECUTE FUNCTION public.archive_project_snapshot();

-- Vuelve a una versión. Con los permisos de quien llama: si no puede editar
-- el proyecto no se actualiza ninguna fila. Lo que había queda en el historial.
CREATE OR REPLACE FUNCTION public.iris_restore_snapshot(p_version BIGINT)
RETURNS VOID
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = public
AS $$
DECLARE
  v cloud_project_snapshot_history%ROWTYPE;
BEGIN
  SELECT * INTO v FROM cloud_project_snapshot_history WHERE id = p_version;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Versión no encontrada';
  END IF;
  PERFORM set_config('iris.force_history', '1', true);
  UPDATE cloud_project_snapshots
  SET content = v.content,
      content_hash = v.content_hash,
      scene_count = v.scene_count,
      shot_count = v.shot_count,
      updated_device = 'Versión restaurada'
  WHERE project_id = v.project_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Sin permiso para editar este proyecto';
  END IF;
END;
$$;

-- La hora del servidor, para comparar ediciones sin depender del reloj de
-- cada equipo.
CREATE OR REPLACE FUNCTION public.iris_server_now()
RETURNS TIMESTAMPTZ
LANGUAGE sql
STABLE
AS $$ SELECT now() $$;

GRANT EXECUTE ON FUNCTION public.iris_restore_snapshot(BIGINT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.iris_server_now() TO authenticated;
