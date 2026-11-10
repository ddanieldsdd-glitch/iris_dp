-- Huella SHA-256 de cada archivo publicado. La app comprueba la descarga con
-- ella antes de instalar; sin la columna, todo sigue funcionando como antes.
alter table public.app_releases add column if not exists sha256 text;
