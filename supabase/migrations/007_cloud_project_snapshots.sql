-- Snapshot JSON del contenido completo de cada proyecto (escenas, planos, etc.)
CREATE TABLE IF NOT EXISTS cloud_project_snapshots (
  project_id UUID PRIMARY KEY REFERENCES cloud_projects(id) ON DELETE CASCADE,
  content JSONB NOT NULL DEFAULT '{}',
  content_hash TEXT,
  scene_count INT NOT NULL DEFAULT 0,
  shot_count INT NOT NULL DEFAULT 0,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_by UUID REFERENCES profiles(id)
);

CREATE INDEX IF NOT EXISTS idx_cloud_project_snapshots_updated
  ON cloud_project_snapshots(updated_at);

CREATE TRIGGER cloud_project_snapshots_updated
  BEFORE UPDATE ON cloud_project_snapshots
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

ALTER TABLE cloud_project_snapshots ENABLE ROW LEVEL SECURITY;

CREATE POLICY snapshot_select ON cloud_project_snapshots FOR SELECT USING (
  project_id IN (SELECT public.owned_workspace_project_ids())
  OR project_id IN (SELECT public.member_project_ids())
);

CREATE POLICY snapshot_insert ON cloud_project_snapshots FOR INSERT WITH CHECK (
  project_id IN (SELECT public.owned_workspace_project_ids())
  OR project_id IN (SELECT public.editable_project_ids())
);

CREATE POLICY snapshot_update ON cloud_project_snapshots FOR UPDATE USING (
  project_id IN (SELECT public.owned_workspace_project_ids())
  OR project_id IN (SELECT public.editable_project_ids())
);

CREATE POLICY snapshot_delete ON cloud_project_snapshots FOR DELETE USING (
  project_id IN (SELECT public.owned_workspace_project_ids())
);
