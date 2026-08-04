-- Perfiles faltantes: usuarios creados en Auth antes del trigger SQL
-- Ejecutar si ves: violates foreign key "workspaces_owner_id_fkey" / Key is not present in table "profiles"

INSERT INTO public.profiles (id, display_name, role)
SELECT
  u.id,
  COALESCE(u.raw_user_meta_data->>'display_name', split_part(u.email, '@', 1), 'Usuario'),
  COALESCE(u.raw_user_meta_data->>'role', 'dp')
FROM auth.users u
LEFT JOIN public.profiles p ON p.id = u.id
WHERE p.id IS NULL;

-- Permite que la app cree su propio perfil si falta
DROP POLICY IF EXISTS profiles_insert ON public.profiles;
CREATE POLICY profiles_insert ON public.profiles
  FOR INSERT WITH CHECK (auth.uid() = id);
