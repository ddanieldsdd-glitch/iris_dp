-- Qué equipo subió la última versión del contenido («editado en iPad hace 2 min»).
-- Las versiones de la app sin esta columna siguen subiendo sin ella.

ALTER TABLE cloud_project_snapshots
  ADD COLUMN IF NOT EXISTS updated_device TEXT;
