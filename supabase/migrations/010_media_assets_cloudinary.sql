-- Cloudinary: metadatos de imágenes sincronizadas (bytes en Cloudinary CDN).

ALTER TABLE media_assets
  ADD COLUMN IF NOT EXISTS provider TEXT NOT NULL DEFAULT 'cloudinary',
  ADD COLUMN IF NOT EXISTS public_id TEXT,
  ADD COLUMN IF NOT EXISTS delivery_url TEXT,
  ADD COLUMN IF NOT EXISTS entity_type TEXT,
  ADD COLUMN IF NOT EXISTS entity_key TEXT,
  ADD COLUMN IF NOT EXISTS content_hash TEXT,
  ADD COLUMN IF NOT EXISTS sort_order INT NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS bytes_original BIGINT,
  ADD COLUMN IF NOT EXISTS bytes_stored BIGINT,
  ADD COLUMN IF NOT EXISTS local_path_hint TEXT;

-- Índice único por entidad lógica dentro del proyecto
CREATE UNIQUE INDEX IF NOT EXISTS idx_media_assets_entity
  ON media_assets (project_id, entity_type, entity_key)
  WHERE entity_type IS NOT NULL AND entity_key IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_media_assets_sort
  ON media_assets (project_id, entity_type, sort_order);

CREATE INDEX IF NOT EXISTS idx_media_assets_hash
  ON media_assets (project_id, content_hash)
  WHERE content_hash IS NOT NULL;
