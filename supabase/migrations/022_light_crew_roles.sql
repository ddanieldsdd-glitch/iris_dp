-- Eléctricos en el equipo del proyecto (plan LZ.3).
-- Ejecutar en Supabase SQL Editor después de 021.
--
-- · Papeles nuevos: best boy (best_boy) y eléctrico (electrician). Son de
--   solo consulta, como «viewer»: ven las plantas de luz, las hojas de luz y
--   el material de cada jornada, pero no cambian nada.
-- · Quién edita lo decide el papel, siempre: un disparador pone can_edit a
--   partir del papel en cada alta o cambio de project_members. Así valen sin
--   tocarlas las funciones que ya dan de alta (iris_accept_invitations, de
--   019, e iris_redeem_invite, de 020) y el cambio de papel desde la app.
--
-- No borra nada y se puede ejecutar más de una vez.

-- ─── Papeles ───────────────────────────────────────────────────────────────

ALTER TABLE public.project_members
  DROP CONSTRAINT IF EXISTS project_members_role_check;
ALTER TABLE public.project_members
  ADD CONSTRAINT project_members_role_check CHECK (role IN (
    'dp', 'director', 'gaffer', 'first_ac', 'camera_assistant', 'first_ad',
    'best_boy', 'electrician', 'viewer'
  ));

ALTER TABLE public.project_invitations
  DROP CONSTRAINT IF EXISTS project_invitations_role_check;
ALTER TABLE public.project_invitations
  ADD CONSTRAINT project_invitations_role_check CHECK (role IN (
    'dp', 'director', 'gaffer', 'first_ac', 'camera_assistant', 'first_ad',
    'best_boy', 'electrician', 'viewer'
  ));

-- La restricción de app_invites (020) se creó sin nombre dentro de la
-- columna: se busca la que habla de project_role y se cambia.
DO $$
DECLARE
  c record;
BEGIN
  FOR c IN
    SELECT conname FROM pg_constraint
    WHERE conrelid = 'public.app_invites'::regclass
      AND contype = 'c'
      AND pg_get_constraintdef(oid) LIKE '%project_role%IN%'
  LOOP
    EXECUTE format('ALTER TABLE public.app_invites DROP CONSTRAINT %I',
                   c.conname);
  END LOOP;
END;
$$;
ALTER TABLE public.app_invites
  ADD CONSTRAINT app_invites_project_role_check CHECK (project_role IN (
    'dp', 'director', 'gaffer', 'first_ac', 'camera_assistant', 'first_ad',
    'best_boy', 'electrician', 'viewer'
  ));

-- ─── Quién edita ───────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.iris_role_can_edit(p_role text)
RETURNS boolean
LANGUAGE sql IMMUTABLE
AS $$
  SELECT p_role IS NULL
      OR p_role NOT IN ('viewer', 'best_boy', 'electrician');
$$;

CREATE OR REPLACE FUNCTION public.iris_members_can_edit_from_role()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.can_edit := public.iris_role_can_edit(NEW.role);
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS project_members_can_edit ON public.project_members;
CREATE TRIGGER project_members_can_edit
  BEFORE INSERT OR UPDATE OF role, can_edit ON public.project_members
  FOR EACH ROW EXECUTE FUNCTION public.iris_members_can_edit_from_role();

-- Las filas que ya hay, por si alguna no cuadra.
UPDATE public.project_members
SET can_edit = public.iris_role_can_edit(role)
WHERE can_edit IS DISTINCT FROM public.iris_role_can_edit(role);

-- ─── Comprobar ─────────────────────────────────────────────────────────────
-- Debe devolver los 9 papeles, el disparador y ninguna fila descuadrada.
SELECT
  pg_get_constraintdef(c.oid) AS papeles,
  (SELECT count(*) FROM pg_trigger WHERE tgname = 'project_members_can_edit')
    AS disparador,
  (SELECT count(*) FROM public.project_members
   WHERE can_edit IS DISTINCT FROM public.iris_role_can_edit(role))
    AS descuadradas
FROM pg_constraint c
WHERE c.conname = 'project_members_role_check';
