-- Storage RLS para bucket project-media (moodboard e imágenes de proyecto)
-- Corrige: 42501 new row violates row-level security policy for table "objects"

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES ('project-media', 'project-media', false, NULL, NULL)
ON CONFLICT (id) DO UPDATE
  SET public = EXCLUDED.public;

-- Extrae el cloud_project_id de rutas: projects/{uuid}/moodboard/archivo.jpg
CREATE OR REPLACE FUNCTION public.storage_object_project_id(object_name text)
RETURNS uuid
LANGUAGE sql
IMMUTABLE
SET search_path = public
AS $$
  SELECT CASE
    WHEN split_part(object_name, '/', 1) = 'projects'
      AND split_part(object_name, '/', 2) ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
    THEN split_part(object_name, '/', 2)::uuid
    ELSE NULL
  END;
$$;

CREATE OR REPLACE FUNCTION public.can_read_storage_object(object_name text)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT public.storage_object_project_id(object_name) IN (
    SELECT public.owned_workspace_project_ids()
    UNION
    SELECT public.member_project_ids()
  );
$$;

CREATE OR REPLACE FUNCTION public.can_write_storage_object(object_name text)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT public.storage_object_project_id(object_name) IN (
    SELECT public.owned_workspace_project_ids()
    UNION
    SELECT public.editable_project_ids()
  );
$$;

GRANT EXECUTE ON FUNCTION public.storage_object_project_id(text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.can_read_storage_object(text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.can_write_storage_object(text) TO authenticated;

DROP POLICY IF EXISTS project_media_select ON storage.objects;
DROP POLICY IF EXISTS project_media_insert ON storage.objects;
DROP POLICY IF EXISTS project_media_update ON storage.objects;
DROP POLICY IF EXISTS project_media_delete ON storage.objects;

CREATE POLICY project_media_select ON storage.objects
  FOR SELECT
  TO authenticated
  USING (
    bucket_id = 'project-media'
    AND public.can_read_storage_object(name)
  );

CREATE POLICY project_media_insert ON storage.objects
  FOR INSERT
  TO authenticated
  WITH CHECK (
    bucket_id = 'project-media'
    AND public.can_write_storage_object(name)
  );

CREATE POLICY project_media_update ON storage.objects
  FOR UPDATE
  TO authenticated
  USING (
    bucket_id = 'project-media'
    AND public.can_write_storage_object(name)
  )
  WITH CHECK (
    bucket_id = 'project-media'
    AND public.can_write_storage_object(name)
  );

CREATE POLICY project_media_delete ON storage.objects
  FOR DELETE
  TO authenticated
  USING (
    bucket_id = 'project-media'
    AND public.can_write_storage_object(name)
  );

-- media_assets: permitir update/delete (upsert de metadatos)
DROP POLICY IF EXISTS media_update ON media_assets;
DROP POLICY IF EXISTS media_delete ON media_assets;

CREATE POLICY media_update ON media_assets FOR UPDATE USING (
  project_id IN (SELECT public.owned_workspace_project_ids())
  OR project_id IN (SELECT public.editable_project_ids())
);

CREATE POLICY media_delete ON media_assets FOR DELETE USING (
  project_id IN (SELECT public.owned_workspace_project_ids())
  OR project_id IN (SELECT public.editable_project_ids())
);
