-- Historial más corto: 8 versiones por proyecto en lugar de 20.
-- Ejecutar DESPUÉS de mirar en Ajustes → Invitados cuánto ocupa el historial.
-- Borra para siempre las versiones antiguas que pasen de 8 por proyecto.

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
        LIMIT 8
      );
  END IF;
  RETURN NEW;
END;
$$;

DELETE FROM cloud_project_snapshot_history h
WHERE h.id IN (
  SELECT id FROM (
    SELECT id, row_number() OVER (
      PARTITION BY project_id ORDER BY saved_at DESC, id DESC
    ) AS n
    FROM cloud_project_snapshot_history
  ) ranked
  WHERE n > 8
);
