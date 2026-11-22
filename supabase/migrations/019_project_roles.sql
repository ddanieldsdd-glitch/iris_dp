-- Equipo del proyecto: papeles e invitaciones (P1, prueba 2).
-- Ejecutar en Supabase SQL Editor después de 018.
--
-- · Papeles nuevos en un proyecto: dirección de fotografía (dp), dirección
--   (director), gaffer, 1.º ayudante de cámara (first_ac), auxiliar de cámara
--   (camera_assistant), 1.º ayudante de dirección (first_ad) y solo consulta
--   (viewer). Todos editan todo salvo «solo consulta».
-- · Aceptar una invitación no funcionaba: la persona invitada intentaba
--   añadirse ella misma a project_members, y solo puede el dueño del
--   proyecto. Ahora lo hace iris_accept_invitations(), en el servidor, solo
--   con las invitaciones dirigidas a su correo.
-- · El dueño puede cambiar el papel de alguien, quitarlo del proyecto y
--   retirar una invitación pendiente.
--
-- No borra nada y se puede ejecutar más de una vez.

-- ─── Papeles ───────────────────────────────────────────────────────────────

ALTER TABLE public.project_members
  DROP CONSTRAINT IF EXISTS project_members_role_check;
ALTER TABLE public.project_members
  ADD CONSTRAINT project_members_role_check CHECK (role IN (
    'dp', 'director', 'gaffer', 'first_ac', 'camera_assistant', 'first_ad',
    'viewer'
  ));

ALTER TABLE public.project_invitations
  DROP CONSTRAINT IF EXISTS project_invitations_role_check;
ALTER TABLE public.project_invitations
  ADD CONSTRAINT project_invitations_role_check CHECK (role IN (
    'dp', 'director', 'gaffer', 'first_ac', 'camera_assistant', 'first_ad',
    'viewer'
  ));

-- ─── Aceptar invitaciones ──────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.iris_accept_invitations()
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  me uuid := auth.uid();
  my_email text := lower(public.current_user_email());
  inv record;
  accepted integer := 0;
BEGIN
  -- Una cuenta aún sin aprobar (016) entra al proyecto cuando se apruebe:
  -- la app lo vuelve a intentar en cada sincronización.
  IF me IS NULL OR my_email IS NULL OR NOT public.app_access_active() THEN
    RETURN 0;
  END IF;
  FOR inv IN
    SELECT id, project_id, role FROM project_invitations
    WHERE lower(email) = my_email AND accepted_at IS NULL
  LOOP
    INSERT INTO project_members (project_id, user_id, role, can_edit)
    VALUES (inv.project_id, me, inv.role, inv.role <> 'viewer')
    ON CONFLICT (project_id, user_id)
      DO UPDATE SET role = EXCLUDED.role, can_edit = EXCLUDED.can_edit;
    UPDATE project_invitations SET accepted_at = now() WHERE id = inv.id;
    accepted := accepted + 1;
  END LOOP;
  RETURN accepted;
END;
$$;

REVOKE ALL ON FUNCTION public.iris_accept_invitations() FROM public, anon;
GRANT EXECUTE ON FUNCTION public.iris_accept_invitations() TO authenticated;

-- ─── El dueño gestiona su equipo ───────────────────────────────────────────

DROP POLICY IF EXISTS pm_update ON public.project_members;
CREATE POLICY pm_update ON public.project_members FOR UPDATE USING (
  project_id IN (SELECT public.owned_workspace_project_ids())
) WITH CHECK (
  project_id IN (SELECT public.owned_workspace_project_ids())
);

DROP POLICY IF EXISTS pm_delete ON public.project_members;
CREATE POLICY pm_delete ON public.project_members FOR DELETE USING (
  project_id IN (SELECT public.owned_workspace_project_ids())
  -- Cada cual puede salir de un proyecto al que lo invitaron.
  OR user_id = auth.uid()
);

DROP POLICY IF EXISTS inv_update ON public.project_invitations;
CREATE POLICY inv_update ON public.project_invitations FOR UPDATE USING (
  project_id IN (SELECT public.owned_workspace_project_ids())
) WITH CHECK (
  project_id IN (SELECT public.owned_workspace_project_ids())
);

DROP POLICY IF EXISTS inv_delete ON public.project_invitations;
CREATE POLICY inv_delete ON public.project_invitations FOR DELETE USING (
  project_id IN (SELECT public.owned_workspace_project_ids())
);

-- ─── Comprobar ─────────────────────────────────────────────────────────────
-- Debe devolver una fila con 7 papeles y la función.
SELECT
  pg_get_constraintdef(c.oid) AS papeles,
  (SELECT count(*) FROM pg_proc WHERE proname = 'iris_accept_invitations')
    AS funcion
FROM pg_constraint c
WHERE c.conname = 'project_members_role_check';
