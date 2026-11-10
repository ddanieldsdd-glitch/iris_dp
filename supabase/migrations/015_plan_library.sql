-- Biblioteca personal de sets y esquemas de luz, común a todos los proyectos.
-- Ejecutar en Supabase SQL Editor después de 014. Sin ella, la biblioteca
-- funciona igual pero se queda en cada equipo.
create table if not exists public.plan_library (
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  uid text not null,
  updated_at timestamptz not null,
  deleted boolean not null default false,
  payload jsonb,
  primary key (user_id, uid)
);

alter table public.plan_library enable row level security;

drop policy if exists plan_library_own on public.plan_library;
create policy plan_library_own on public.plan_library
  for all using (user_id = auth.uid()) with check (user_id = auth.uid());
