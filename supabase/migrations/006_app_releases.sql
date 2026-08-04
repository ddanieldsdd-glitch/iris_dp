-- Metadatos de releases (plan gratis: solo tabla, sin Storage de instaladores).
-- Los .dmg / .zip viven en GitHub Releases; aquí solo version + URL.

CREATE TABLE IF NOT EXISTS app_releases (
  platform TEXT NOT NULL CHECK (platform IN ('macos', 'windows', 'ipad')),
  version TEXT NOT NULL,
  build_number INT NOT NULL,
  download_url TEXT NOT NULL,
  release_notes TEXT,
  published_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (platform, build_number)
);

CREATE INDEX IF NOT EXISTS app_releases_platform_build_idx
  ON app_releases (platform, build_number DESC);

ALTER TABLE app_releases ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS app_releases_select ON app_releases;
CREATE POLICY app_releases_select ON app_releases
  FOR SELECT TO authenticated
  USING (true);

-- Escritura solo vía service role (GitHub Actions o SQL manual del DP).
