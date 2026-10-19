-- Perfiles visibles para el equipo, fotos de perfil y espacio usado en la nube.
-- Ejecutar en Supabase SQL Editor después de 011.

-- ─── Perfiles: cada uno edita el suyo; lee los de su equipo ────────────────

-- ¿Comparte el usuario actual workspace o proyecto con `target`?
CREATE OR REPLACE FUNCTION public.can_see_profile(target uuid)
RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public
AS $$
  SELECT target = auth.uid()
  -- Mismo workspace
  OR EXISTS (
    SELECT 1 FROM workspace_members a
    JOIN workspace_members b ON b.workspace_id = a.workspace_id
    WHERE a.user_id = auth.uid() AND b.user_id = target
  )
  -- Mismo proyecto
  OR EXISTS (
    SELECT 1 FROM project_members a
    JOIN project_members b ON b.project_id = a.project_id
    WHERE a.user_id = auth.uid() AND b.user_id = target
  )
  -- Director ↔ miembros del workspace dueño de su proyecto
  OR EXISTS (
    SELECT 1 FROM project_members pm
    JOIN cloud_projects cp ON cp.id = pm.project_id
    JOIN workspace_members wm ON wm.workspace_id = cp.workspace_id
    WHERE (pm.user_id = auth.uid() AND wm.user_id = target)
       OR (wm.user_id = auth.uid() AND pm.user_id = target)
  );
$$;

GRANT EXECUTE ON FUNCTION public.can_see_profile(uuid) TO authenticated;

DROP POLICY IF EXISTS profiles_select ON public.profiles;
CREATE POLICY profiles_select ON public.profiles
  FOR SELECT USING (public.can_see_profile(id));

-- Personas de un workspace: miembros del workspace y de sus proyectos.
CREATE OR REPLACE FUNCTION public.workspace_member_profiles(ws uuid)
RETURNS TABLE (
  id uuid,
  display_name text,
  avatar_url text,
  role text,
  updated_at timestamptz
)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public
AS $$
  WITH people AS (
    SELECT wm.user_id, wm.role FROM workspace_members wm
    WHERE wm.workspace_id = ws
    UNION
    SELECT pm.user_id, pm.role FROM project_members pm
    JOIN cloud_projects cp ON cp.id = pm.project_id
    WHERE cp.workspace_id = ws
  ),
  allowed AS (
    SELECT 1 WHERE EXISTS (SELECT 1 FROM people WHERE user_id = auth.uid())
  )
  SELECT DISTINCT ON (p.id)
    p.id, p.display_name, p.avatar_url, people.role, p.updated_at
  FROM people
  JOIN profiles p ON p.id = people.user_id
  WHERE EXISTS (SELECT 1 FROM allowed)
  ORDER BY p.id,
    CASE people.role WHEN 'owner' THEN 0 WHEN 'dp' THEN 1
      WHEN 'director' THEN 2 ELSE 3 END;
$$;

REVOKE ALL ON FUNCTION public.workspace_member_profiles(uuid) FROM public, anon;
GRANT EXECUTE ON FUNCTION public.workspace_member_profiles(uuid) TO authenticated;

-- ─── Fotos de perfil: bucket público, cada uno escribe en su carpeta ───────
-- Ruta: avatars/{user_id}/avatar.jpg

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES ('avatars', 'avatars', true, 2097152, ARRAY['image/jpeg', 'image/png'])
ON CONFLICT (id) DO UPDATE
  SET public = EXCLUDED.public,
      file_size_limit = EXCLUDED.file_size_limit,
      allowed_mime_types = EXCLUDED.allowed_mime_types;

DROP POLICY IF EXISTS avatars_select ON storage.objects;
CREATE POLICY avatars_select ON storage.objects
  FOR SELECT TO authenticated
  USING (bucket_id = 'avatars');

DROP POLICY IF EXISTS avatars_insert ON storage.objects;
CREATE POLICY avatars_insert ON storage.objects
  FOR INSERT TO authenticated
  WITH CHECK (
    bucket_id = 'avatars'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

DROP POLICY IF EXISTS avatars_update ON storage.objects;
CREATE POLICY avatars_update ON storage.objects
  FOR UPDATE TO authenticated
  USING (
    bucket_id = 'avatars'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

DROP POLICY IF EXISTS avatars_delete ON storage.objects;
CREATE POLICY avatars_delete ON storage.objects
  FOR DELETE TO authenticated
  USING (
    bucket_id = 'avatars'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

-- ─── Espacio usado (Ajustes) ───────────────────────────────────────────────
-- Totales del proyecto Supabase (lo que cuenta para la cuota) y bytes de
-- Cloudinary según los registros de media_assets (estimación: Cloudinary no
-- expone su uso sin la clave secreta).

CREATE OR REPLACE FUNCTION public.iris_storage_usage()
RETURNS jsonb
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, storage
AS $$
  SELECT jsonb_build_object(
    'database_bytes', pg_database_size(current_database()),
    'storage_bytes', COALESCE(
      (SELECT sum((metadata->>'size')::bigint) FROM storage.objects), 0),
    'storage_buckets', COALESCE(
      (SELECT jsonb_object_agg(bucket_id, bytes) FROM (
        SELECT bucket_id, sum((metadata->>'size')::bigint) AS bytes
        FROM storage.objects GROUP BY bucket_id
      ) b), '{}'::jsonb),
    'cloudinary_bytes', COALESCE(
      (SELECT sum(COALESCE(bytes_stored, bytes_original, 0))
       FROM media_assets WHERE provider = 'cloudinary'), 0),
    'cloudinary_assets',
      (SELECT count(*) FROM media_assets WHERE provider = 'cloudinary'),
    'measured_at', now()
  );
$$;

REVOKE ALL ON FUNCTION public.iris_storage_usage() FROM public, anon;
GRANT EXECUTE ON FUNCTION public.iris_storage_usage() TO authenticated;
