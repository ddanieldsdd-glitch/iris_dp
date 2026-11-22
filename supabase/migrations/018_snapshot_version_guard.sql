-- Guarda de versión del contenido (plan R).
-- Una app antigua no puede sustituir en la nube un proyecto guardado con un
-- formato más nuevo (`content->'version'`): perdería lo que ella no sabe
-- leer. La app nueva ya se niega a bajarlo o mezclarlo (`assertReadable`);
-- esto cierra la otra puerta, la subida, también para las versiones que no
-- llevan esa comprobación.
--
-- No borra nada y se puede ejecutar más de una vez.

CREATE OR REPLACE FUNCTION public.guard_snapshot_version()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = public
AS $$
DECLARE
  old_v NUMERIC;
  new_v NUMERIC;
BEGIN
  IF jsonb_typeof(OLD.content -> 'version') = 'number' THEN
    old_v := (OLD.content ->> 'version')::NUMERIC;
  END IF;
  IF jsonb_typeof(NEW.content -> 'version') = 'number' THEN
    new_v := (NEW.content ->> 'version')::NUMERIC;
  END IF;
  -- Sin versión en la copia de la nube (proyectos muy antiguos o vacíos):
  -- no hay nada que proteger.
  IF old_v IS NOT NULL AND coalesce(new_v, 0) < old_v THEN
    RAISE EXCEPTION 'IRIS_SNAPSHOT_OLDER_VERSION'
      USING DETAIL = format('nube v%s, subida v%s', old_v, coalesce(new_v, 0)),
            HINT = 'Actualiza IRIS en este equipo para seguir sincronizando.';
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS cloud_project_snapshots_version_guard
  ON public.cloud_project_snapshots;
CREATE TRIGGER cloud_project_snapshots_version_guard
  BEFORE UPDATE OF content ON public.cloud_project_snapshots
  FOR EACH ROW EXECUTE FUNCTION public.guard_snapshot_version();

-- Comprobación: debe devolver una fila.
SELECT tgname FROM pg_trigger
WHERE tgname = 'cloud_project_snapshots_version_guard';
