-- IRIS DP Cloud — esquema inicial + RLS
-- Ejecutar en Supabase SQL Editor

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Perfiles (extiende auth.users)
CREATE TABLE IF NOT EXISTS profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  display_name TEXT NOT NULL DEFAULT '',
  role TEXT NOT NULL DEFAULT 'dp' CHECK (role IN ('dp', 'director')),
  avatar_url TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS workspaces (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name TEXT NOT NULL,
  owner_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS workspace_members (
  workspace_id UUID NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  role TEXT NOT NULL DEFAULT 'collaborator' CHECK (role IN ('owner', 'collaborator')),
  PRIMARY KEY (workspace_id, user_id)
);

CREATE TABLE IF NOT EXISTS cloud_projects (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  workspace_id UUID NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  director_display TEXT,
  description TEXT,
  client_name TEXT,
  status TEXT NOT NULL DEFAULT 'preproduction',
  icon_code INT NOT NULL DEFAULT 58228,
  cover_storage_path TEXT,
  shooting_start_date TEXT,
  shooting_end_date TEXT,
  sort_order INT NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS project_members (
  project_id UUID NOT NULL REFERENCES cloud_projects(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  role TEXT NOT NULL CHECK (role IN ('dp', 'director', 'viewer')),
  can_edit BOOLEAN NOT NULL DEFAULT true,
  PRIMARY KEY (project_id, user_id)
);

CREATE TABLE IF NOT EXISTS project_invitations (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  project_id UUID NOT NULL REFERENCES cloud_projects(id) ON DELETE CASCADE,
  email TEXT NOT NULL,
  role TEXT NOT NULL DEFAULT 'director' CHECK (role IN ('director', 'viewer')),
  invited_by UUID NOT NULL REFERENCES profiles(id),
  accepted_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (project_id, email)
);

CREATE TABLE IF NOT EXISTS media_assets (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  project_id UUID NOT NULL REFERENCES cloud_projects(id) ON DELETE CASCADE,
  storage_path TEXT NOT NULL,
  local_hash TEXT,
  mime_type TEXT,
  category TEXT,
  sort_order INT NOT NULL DEFAULT 0,
  metadata JSONB DEFAULT '{}',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_cloud_projects_workspace ON cloud_projects(workspace_id);
CREATE INDEX IF NOT EXISTS idx_project_members_user ON project_members(user_id);
CREATE INDEX IF NOT EXISTS idx_media_assets_project ON media_assets(project_id);

-- Trigger updated_at
CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER profiles_updated BEFORE UPDATE ON profiles
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER workspaces_updated BEFORE UPDATE ON workspaces
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER cloud_projects_updated BEFORE UPDATE ON cloud_projects
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER media_assets_updated BEFORE UPDATE ON media_assets
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- Auto-create profile on signup
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO profiles (id, display_name, role)
  VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data->>'display_name', split_part(NEW.email, '@', 1)),
    COALESCE(NEW.raw_user_meta_data->>'role', 'dp')
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION handle_new_user();

-- RLS
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE workspaces ENABLE ROW LEVEL SECURITY;
ALTER TABLE workspace_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE cloud_projects ENABLE ROW LEVEL SECURITY;
ALTER TABLE project_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE project_invitations ENABLE ROW LEVEL SECURITY;
ALTER TABLE media_assets ENABLE ROW LEVEL SECURITY;

-- Profiles: own row
CREATE POLICY profiles_select ON profiles FOR SELECT USING (auth.uid() = id);
CREATE POLICY profiles_update ON profiles FOR UPDATE USING (auth.uid() = id);
CREATE POLICY profiles_insert ON profiles FOR INSERT WITH CHECK (auth.uid() = id);

-- Helpers RLS (SECURITY DEFINER evita recursión workspaces ↔ workspace_members)
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

-- Workspaces: owner o miembro
CREATE POLICY workspaces_select ON workspaces FOR SELECT USING (
  owner_id = auth.uid()
  OR id IN (SELECT public.member_workspace_ids())
);

CREATE POLICY workspaces_insert ON workspaces FOR INSERT
  WITH CHECK (owner_id = auth.uid());

-- Workspace members
CREATE POLICY wm_select ON workspace_members FOR SELECT USING (
  user_id = auth.uid()
  OR workspace_id IN (SELECT public.owned_workspace_ids())
);

CREATE POLICY wm_insert ON workspace_members FOR INSERT WITH CHECK (
  user_id = auth.uid()
  AND workspace_id IN (SELECT public.owned_workspace_ids())
);

-- Projects: owner ve todo su workspace; director solo asignados
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

CREATE POLICY projects_select ON cloud_projects FOR SELECT USING (
  workspace_id IN (SELECT public.owned_workspace_ids())
  OR id IN (SELECT public.member_project_ids())
);

CREATE POLICY projects_insert ON cloud_projects FOR INSERT WITH CHECK (
  workspace_id IN (SELECT public.owned_workspace_ids())
);

CREATE POLICY projects_update ON cloud_projects FOR UPDATE USING (
  workspace_id IN (SELECT public.owned_workspace_ids())
  OR id IN (SELECT public.editable_project_ids())
);

CREATE POLICY projects_delete ON cloud_projects FOR DELETE USING (
  workspace_id IN (SELECT public.owned_workspace_ids())
);

-- Project members
CREATE POLICY pm_select ON project_members FOR SELECT USING (
  user_id = auth.uid()
  OR project_id IN (SELECT public.owned_workspace_project_ids())
);

CREATE POLICY pm_insert ON project_members FOR INSERT WITH CHECK (
  project_id IN (SELECT public.owned_workspace_project_ids())
);

-- Invitations (owner only)
CREATE POLICY inv_select ON project_invitations FOR SELECT USING (
  project_id IN (SELECT public.owned_workspace_project_ids())
  OR email = public.current_user_email()
);

CREATE POLICY inv_insert ON project_invitations FOR INSERT WITH CHECK (
  project_id IN (SELECT public.owned_workspace_project_ids())
);

-- Media assets
CREATE POLICY media_select ON media_assets FOR SELECT USING (
  project_id IN (SELECT public.owned_workspace_project_ids())
  OR project_id IN (SELECT public.member_project_ids())
);

CREATE POLICY media_insert ON media_assets FOR INSERT WITH CHECK (
  project_id IN (SELECT public.owned_workspace_project_ids())
  OR project_id IN (SELECT public.editable_project_ids())
);

-- Storage bucket policy (ejecutar aparte en Storage policies UI o):
-- Bucket: project-media
-- Path: projects/{project_id}/...
