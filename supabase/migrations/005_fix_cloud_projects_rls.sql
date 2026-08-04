-- Fix: recursión RLS en cloud_projects, project_members, invitations, media
-- Ejecutar si ves: infinite recursion detected in policy for relation "cloud_projects"

CREATE OR REPLACE FUNCTION public.member_project_ids()
RETURNS SETOF uuid
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public
AS $$
  SELECT project_id FROM project_members WHERE user_id = auth.uid();
$$;

CREATE OR REPLACE FUNCTION public.editable_project_ids()
RETURNS SETOF uuid
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public
AS $$
  SELECT project_id FROM project_members
  WHERE user_id = auth.uid() AND can_edit = true;
$$;

CREATE OR REPLACE FUNCTION public.owned_workspace_project_ids()
RETURNS SETOF uuid
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public
AS $$
  SELECT cp.id FROM cloud_projects cp
  WHERE cp.workspace_id IN (SELECT id FROM workspaces WHERE owner_id = auth.uid());
$$;

CREATE OR REPLACE FUNCTION public.current_user_email()
RETURNS text
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public
AS $$
  SELECT email FROM auth.users WHERE id = auth.uid();
$$;

GRANT EXECUTE ON FUNCTION public.member_project_ids() TO authenticated;
GRANT EXECUTE ON FUNCTION public.editable_project_ids() TO authenticated;
GRANT EXECUTE ON FUNCTION public.owned_workspace_project_ids() TO authenticated;
GRANT EXECUTE ON FUNCTION public.current_user_email() TO authenticated;

-- cloud_projects
DROP POLICY IF EXISTS projects_select ON cloud_projects;
CREATE POLICY projects_select ON cloud_projects FOR SELECT USING (
  workspace_id IN (SELECT public.owned_workspace_ids())
  OR id IN (SELECT public.member_project_ids())
);

DROP POLICY IF EXISTS projects_insert ON cloud_projects;
CREATE POLICY projects_insert ON cloud_projects FOR INSERT WITH CHECK (
  workspace_id IN (SELECT public.owned_workspace_ids())
);

DROP POLICY IF EXISTS projects_update ON cloud_projects;
CREATE POLICY projects_update ON cloud_projects FOR UPDATE USING (
  workspace_id IN (SELECT public.owned_workspace_ids())
  OR id IN (SELECT public.editable_project_ids())
);

DROP POLICY IF EXISTS projects_delete ON cloud_projects;
CREATE POLICY projects_delete ON cloud_projects FOR DELETE USING (
  workspace_id IN (SELECT public.owned_workspace_ids())
);

-- project_members
DROP POLICY IF EXISTS pm_select ON project_members;
CREATE POLICY pm_select ON project_members FOR SELECT USING (
  user_id = auth.uid()
  OR project_id IN (SELECT public.owned_workspace_project_ids())
);

DROP POLICY IF EXISTS pm_insert ON project_members;
CREATE POLICY pm_insert ON project_members FOR INSERT WITH CHECK (
  project_id IN (SELECT public.owned_workspace_project_ids())
);

-- invitations
DROP POLICY IF EXISTS inv_select ON project_invitations;
CREATE POLICY inv_select ON project_invitations FOR SELECT USING (
  project_id IN (SELECT public.owned_workspace_project_ids())
  OR email = public.current_user_email()
);

DROP POLICY IF EXISTS inv_insert ON project_invitations;
CREATE POLICY inv_insert ON project_invitations FOR INSERT WITH CHECK (
  project_id IN (SELECT public.owned_workspace_project_ids())
);

-- media_assets
DROP POLICY IF EXISTS media_select ON media_assets;
CREATE POLICY media_select ON media_assets FOR SELECT USING (
  project_id IN (SELECT public.owned_workspace_project_ids())
  OR project_id IN (SELECT public.member_project_ids())
);

DROP POLICY IF EXISTS media_insert ON media_assets;
CREATE POLICY media_insert ON media_assets FOR INSERT WITH CHECK (
  project_id IN (SELECT public.owned_workspace_project_ids())
  OR project_id IN (SELECT public.editable_project_ids())
);
