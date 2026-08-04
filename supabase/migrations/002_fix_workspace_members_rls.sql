-- Fix completo RLS (mismo contenido que 003). Ejecutar 003 si aún no lo hiciste.

CREATE OR REPLACE FUNCTION public.owned_workspace_ids()
RETURNS SETOF uuid
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT id FROM workspaces WHERE owner_id = auth.uid();
$$;

CREATE OR REPLACE FUNCTION public.member_workspace_ids()
RETURNS SETOF uuid
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT workspace_id FROM workspace_members WHERE user_id = auth.uid();
$$;

GRANT EXECUTE ON FUNCTION public.owned_workspace_ids() TO authenticated;
GRANT EXECUTE ON FUNCTION public.member_workspace_ids() TO authenticated;

DROP POLICY IF EXISTS workspaces_select ON workspaces;
CREATE POLICY workspaces_select ON workspaces FOR SELECT USING (
  owner_id = auth.uid()
  OR id IN (SELECT public.member_workspace_ids())
);

DROP POLICY IF EXISTS wm_select ON workspace_members;
CREATE POLICY wm_select ON workspace_members FOR SELECT USING (
  user_id = auth.uid()
  OR workspace_id IN (SELECT public.owned_workspace_ids())
);

DROP POLICY IF EXISTS wm_insert ON workspace_members;
CREATE POLICY wm_insert ON workspace_members FOR INSERT WITH CHECK (
  user_id = auth.uid()
  AND workspace_id IN (SELECT public.owned_workspace_ids())
);
