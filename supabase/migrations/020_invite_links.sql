-- Invitar con un enlace o con el correo, y el plan de cada cuenta.
-- Ejecutar en Supabase SQL Editor después de 019.
--
-- · Una invitación es un código (10 letras y números, «K7M2-QX9P-4C») que
--   va dentro de un enlace. Puede ser:
--     - a IRIS (solo el administrador): quien la usa entra sin esperar
--       aprobación, como «probador» y gratis;
--     - a un proyecto con un papel (el dueño del proyecto). Si la crea el
--       administrador, además da acceso a IRIS;
--     - para un correo concreto (solo esa cuenta puede usarla, y se aplica
--       sola al entrar con ese correo) o para cualquiera que tenga el enlace,
--       con un número de usos.
--   Los enlaces caducan (30 días por defecto) y se pueden retirar.
-- · Cada cuenta tiene un plan (probador, prueba, pro, equipo) y, si
--   caduca, hasta cuándo. Hoy todos son probadores sin fecha; el pago (tienda
--   de Apple, Stripe…) escribirá aquí más adelante sin cambiar la app.
--
-- No borra nada y se puede ejecutar más de una vez.

-- ─── Plan de cada cuenta ───────────────────────────────────────────────────

ALTER TABLE public.app_access
  ADD COLUMN IF NOT EXISTS plan TEXT NOT NULL DEFAULT 'tester';
ALTER TABLE public.app_access
  DROP CONSTRAINT IF EXISTS app_access_plan_check;
ALTER TABLE public.app_access
  ADD CONSTRAINT app_access_plan_check
  CHECK (plan IN ('tester', 'trial', 'pro', 'team'));
-- Nulo: no caduca.
ALTER TABLE public.app_access
  ADD COLUMN IF NOT EXISTS plan_expires_at TIMESTAMPTZ;
ALTER TABLE public.app_access
  ADD COLUMN IF NOT EXISTS invited_by UUID
  REFERENCES auth.users(id) ON DELETE SET NULL;
-- De dónde viene el acceso: manual, invite, store, stripe…
ALTER TABLE public.app_access
  ADD COLUMN IF NOT EXISTS source TEXT;

-- Un plan caducado cierra la escritura igual que una cuenta sin aprobar.
CREATE OR REPLACE FUNCTION public.app_access_active()
RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.app_access a
    WHERE a.user_id = auth.uid() AND a.status = 'active'
      AND (a.role = 'admin' OR a.plan_expires_at IS NULL
           OR a.plan_expires_at > now())
      AND (a.role = 'admin'
           OR NOT COALESCE((SELECT maintenance FROM public.app_state WHERE id = 1), false))
  );
$$;

-- Lo mismo que en 016, más el plan. Con el plan caducado el estado sale
-- «expired» (las versiones de la app sin este cambio lo leen como pendiente).
CREATE OR REPLACE FUNCTION public.iris_access_check()
RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  a app_access%ROWTYPE;
  s app_state%ROWTYPE;
  ws uuid;
  used bigint;
  st text;
BEGIN
  SELECT * INTO a FROM app_access WHERE user_id = auth.uid();
  SELECT * INTO s FROM app_state WHERE id = 1;
  IF a.storage_limit_bytes IS NOT NULL THEN
    SELECT w.id INTO ws FROM workspaces w
    WHERE w.owner_id = auth.uid() ORDER BY w.created_at LIMIT 1;
    IF ws IS NOT NULL THEN
      SELECT u.content_bytes + u.history_bytes + u.media_bytes INTO used
      FROM public.workspace_usage_bytes(ws) u;
    END IF;
  END IF;
  st := COALESCE(a.status, 'pending');
  IF st = 'active' AND a.role <> 'admin' AND a.plan_expires_at IS NOT NULL
     AND a.plan_expires_at <= now() THEN
    st := 'expired';
  END IF;
  RETURN jsonb_build_object(
    'status', st,
    'role', COALESCE(a.role, 'guest'),
    'message', a.message,
    'plan', COALESCE(a.plan, 'tester'),
    'plan_expires_at', a.plan_expires_at,
    'storage_limit_bytes', a.storage_limit_bytes,
    'used_bytes', used,
    'maintenance', COALESCE(s.maintenance, false),
    'maintenance_message', s.message,
    'min_build', COALESCE(s.min_build, 0),
    'server_time', now()
  );
END;
$$;

REVOKE ALL ON FUNCTION public.iris_access_check() FROM public, anon;
GRANT EXECUTE ON FUNCTION public.iris_access_check() TO authenticated;

-- ─── Invitaciones ──────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.app_invites (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  code TEXT NOT NULL UNIQUE,
  created_by UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  -- Solo esta cuenta puede usarla. Nulo: cualquiera con el enlace.
  email TEXT,
  project_id UUID REFERENCES public.cloud_projects(id) ON DELETE CASCADE,
  project_role TEXT CHECK (project_role IN (
    'dp', 'director', 'gaffer', 'first_ac', 'camera_assistant', 'first_ad',
    'viewer'
  )),
  -- Da acceso a IRIS: solo si la creó el administrador.
  grants_access BOOLEAN NOT NULL DEFAULT false,
  plan TEXT NOT NULL DEFAULT 'tester'
    CHECK (plan IN ('tester', 'trial', 'pro', 'team')),
  -- Días que dura el plan desde que se usa. Nulo: sin fecha.
  plan_days INT CHECK (plan_days IS NULL OR plan_days > 0),
  max_uses INT NOT NULL DEFAULT 1 CHECK (max_uses BETWEEN 1 AND 100),
  uses INT NOT NULL DEFAULT 0,
  expires_at TIMESTAMPTZ NOT NULL DEFAULT now() + interval '30 days',
  revoked_at TIMESTAMPTZ,
  note TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CHECK ((project_id IS NULL) = (project_role IS NULL))
);

CREATE TABLE IF NOT EXISTS public.app_invite_redemptions (
  invite_id UUID NOT NULL REFERENCES public.app_invites(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  redeemed_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (invite_id, user_id)
);

CREATE INDEX IF NOT EXISTS app_invites_email_idx
  ON public.app_invites (lower(email)) WHERE email IS NOT NULL;

ALTER TABLE public.app_invites ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.app_invite_redemptions ENABLE ROW LEVEL SECURITY;

-- Cada cual ve las que ha creado; el administrador, todas. Se escriben solo
-- con las funciones de abajo.
DROP POLICY IF EXISTS app_invites_select ON public.app_invites;
CREATE POLICY app_invites_select ON public.app_invites
  FOR SELECT TO authenticated
  USING (created_by = auth.uid() OR public.is_app_admin());

DROP POLICY IF EXISTS app_invite_redemptions_select
  ON public.app_invite_redemptions;
CREATE POLICY app_invite_redemptions_select ON public.app_invite_redemptions
  FOR SELECT TO authenticated
  USING (
    user_id = auth.uid() OR public.is_app_admin()
    OR invite_id IN (SELECT id FROM public.app_invites
                     WHERE created_by = auth.uid())
  );

-- Código sin signos que se confunden (sin 0/O ni 1/I). 32 signos: cada byte
-- aleatorio da uno sin sesgo.
CREATE OR REPLACE FUNCTION public.iris_new_invite_code()
RETURNS text
LANGUAGE plpgsql VOLATILE SET search_path = public
AS $$
DECLARE
  alphabet constant text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  b bytea;
  out text;
BEGIN
  LOOP
    b := decode(replace(gen_random_uuid()::text, '-', ''), 'hex');
    out := '';
    -- Los bytes 6 y 8 del uuid llevan la versión y la variante: se saltan.
    FOR i IN 0..15 LOOP
      CONTINUE WHEN i IN (6, 8);
      out := out || substr(alphabet, (get_byte(b, i) % 32) + 1, 1);
      EXIT WHEN length(out) = 10;
    END LOOP;
    EXIT WHEN NOT EXISTS (SELECT 1 FROM app_invites WHERE code = out);
  END LOOP;
  RETURN out;
END;
$$;

REVOKE ALL ON FUNCTION public.iris_new_invite_code() FROM public, anon, authenticated;

-- Quita guiones y espacios: «k7m2-qx9p 4c» → «K7M2QX9P4C».
CREATE OR REPLACE FUNCTION public.iris_normalize_invite_code(c text)
RETURNS text
LANGUAGE sql IMMUTABLE
AS $$
  SELECT upper(regexp_replace(COALESCE(c, ''), '[^A-Za-z0-9]', '', 'g'));
$$;

-- Crea una invitación. Devuelve {id, code, grants_access, expires_at}.
CREATE OR REPLACE FUNCTION public.iris_create_invite(
  p_project uuid DEFAULT NULL,
  p_role text DEFAULT NULL,
  p_email text DEFAULT NULL,
  p_max_uses int DEFAULT 1,
  p_valid_days int DEFAULT 30,
  p_plan_days int DEFAULT NULL,
  p_note text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  me uuid := auth.uid();
  admin boolean := public.is_app_admin();
  mail text := NULLIF(lower(trim(p_email)), '');
  inv app_invites%ROWTYPE;
BEGIN
  IF me IS NULL OR NOT public.app_access_active() THEN
    RAISE EXCEPTION 'IRIS_INVITE_FORBIDDEN';
  END IF;
  IF p_project IS NULL THEN
    -- Invitar a IRIS sin proyecto: solo el administrador.
    IF NOT admin THEN RAISE EXCEPTION 'IRIS_INVITE_FORBIDDEN'; END IF;
  ELSE
    IF p_project NOT IN (SELECT public.owned_workspace_project_ids()) THEN
      RAISE EXCEPTION 'IRIS_INVITE_FORBIDDEN';
    END IF;
    IF p_role IS NULL THEN RAISE EXCEPTION 'IRIS_INVITE_ROLE'; END IF;
  END IF;
  IF mail IS NOT NULL AND mail !~ '^[^@\s]+@[^@\s]+\.[^@\s]+$' THEN
    RAISE EXCEPTION 'IRIS_INVITE_EMAIL';
  END IF;

  INSERT INTO app_invites (
    code, created_by, email, project_id, project_role, grants_access,
    plan_days, max_uses, expires_at, note
  ) VALUES (
    public.iris_new_invite_code(), me, mail, p_project, p_role, admin,
    p_plan_days,
    CASE WHEN mail IS NOT NULL THEN 1
         ELSE LEAST(GREATEST(COALESCE(p_max_uses, 1), 1), 100) END,
    now() + make_interval(days => LEAST(GREATEST(COALESCE(p_valid_days, 30), 1), 365)),
    NULLIF(trim(p_note), '')
  ) RETURNING * INTO inv;

  -- Con correo y proyecto, también la invitación de siempre: quien ya usa
  -- IRIS con ese correo entra al proyecto en su próxima sincronización.
  IF mail IS NOT NULL AND p_project IS NOT NULL THEN
    INSERT INTO project_invitations (project_id, email, role, invited_by)
    VALUES (p_project, mail, p_role, me)
    ON CONFLICT (project_id, email)
      DO UPDATE SET role = EXCLUDED.role, accepted_at = NULL;
  END IF;

  RETURN jsonb_build_object(
    'id', inv.id, 'code', inv.code, 'grants_access', inv.grants_access,
    'expires_at', inv.expires_at
  );
END;
$$;

REVOKE ALL ON FUNCTION public.iris_create_invite(uuid, text, text, int, int, int, text) FROM public, anon;
GRANT EXECUTE ON FUNCTION public.iris_create_invite(uuid, text, text, int, int, int, text) TO authenticated;

-- Usa una invitación. Con código, esa (y si no vale, dice por qué con
-- IRIS_INVITE_<motivo>). Sin código, todas las que hay para el correo de la
-- cuenta. Devuelve {redeemed, access, projects}.
CREATE OR REPLACE FUNCTION public.iris_redeem_invite(p_code text DEFAULT NULL)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  me uuid := auth.uid();
  my_email text := lower(public.current_user_email());
  wanted text := NULLIF(public.iris_normalize_invite_code(p_code), '');
  inv app_invites%ROWTYPE;
  acc app_access%ROWTYPE;
  redeemed int := 0;
  granted boolean := false;
  projects uuid[] := '{}';
BEGIN
  IF me IS NULL OR my_email IS NULL THEN
    RAISE EXCEPTION 'IRIS_INVITE_SIGNIN';
  END IF;

  IF wanted IS NOT NULL THEN
    SELECT * INTO inv FROM app_invites WHERE code = wanted FOR UPDATE;
    IF NOT FOUND THEN RAISE EXCEPTION 'IRIS_INVITE_UNKNOWN'; END IF;
    IF EXISTS (SELECT 1 FROM app_invite_redemptions
               WHERE invite_id = inv.id AND user_id = me) THEN
      RETURN jsonb_build_object('redeemed', 0, 'access', false,
                                'projects', '[]'::jsonb);
    END IF;
    IF inv.revoked_at IS NOT NULL THEN RAISE EXCEPTION 'IRIS_INVITE_REVOKED'; END IF;
    IF inv.expires_at <= now() THEN RAISE EXCEPTION 'IRIS_INVITE_EXPIRED'; END IF;
    IF inv.uses >= inv.max_uses THEN RAISE EXCEPTION 'IRIS_INVITE_USED'; END IF;
    IF inv.email IS NOT NULL AND lower(inv.email) <> my_email THEN
      RAISE EXCEPTION 'IRIS_INVITE_OTHER_EMAIL';
    END IF;
  END IF;

  FOR inv IN
    SELECT * FROM app_invites i
    WHERE (CASE WHEN wanted IS NOT NULL THEN i.code = wanted
                ELSE lower(i.email) = my_email END)
      AND i.revoked_at IS NULL AND i.expires_at > now()
      AND i.uses < i.max_uses
      AND (i.email IS NULL OR lower(i.email) = my_email)
      AND NOT EXISTS (SELECT 1 FROM app_invite_redemptions r
                      WHERE r.invite_id = i.id AND r.user_id = me)
    ORDER BY i.created_at
    FOR UPDATE
  LOOP
    IF inv.grants_access THEN
      INSERT INTO app_access (user_id, role, status)
      VALUES (me, 'guest', 'pending')
      ON CONFLICT (user_id) DO NOTHING;
      SELECT * INTO acc FROM app_access WHERE user_id = me;
      -- Una cuenta que el administrador cerró no se reabre con un enlace.
      IF acc.status = 'pending'
         OR (acc.status = 'active' AND acc.plan_expires_at IS NOT NULL) THEN
        UPDATE app_access SET
          status = 'active',
          plan = inv.plan,
          plan_expires_at = CASE WHEN inv.plan_days IS NULL THEN NULL
                                 ELSE now() + make_interval(days => inv.plan_days) END,
          invited_by = COALESCE(invited_by, inv.created_by),
          source = COALESCE(source, 'invite')
        WHERE user_id = me;
        granted := true;
      END IF;
    END IF;

    IF inv.project_id IS NOT NULL THEN
      INSERT INTO project_members (project_id, user_id, role, can_edit)
      VALUES (inv.project_id, me, inv.project_role,
              inv.project_role <> 'viewer')
      ON CONFLICT (project_id, user_id)
        DO UPDATE SET role = EXCLUDED.role, can_edit = EXCLUDED.can_edit;
      UPDATE project_invitations SET accepted_at = now()
      WHERE project_id = inv.project_id AND lower(email) = my_email
        AND accepted_at IS NULL;
      projects := projects || inv.project_id;
    END IF;

    UPDATE app_invites SET uses = uses + 1 WHERE id = inv.id;
    INSERT INTO app_invite_redemptions (invite_id, user_id) VALUES (inv.id, me);
    redeemed := redeemed + 1;
  END LOOP;

  RETURN jsonb_build_object(
    'redeemed', redeemed, 'access', granted, 'projects', to_jsonb(projects)
  );
END;
$$;

REVOKE ALL ON FUNCTION public.iris_redeem_invite(text) FROM public, anon;
GRANT EXECUTE ON FUNCTION public.iris_redeem_invite(text) TO authenticated;

-- Retira una invitación (quien la creó o el administrador). Quien ya la usó
-- sigue dentro: para sacarlo, «Equipo del proyecto» o el panel de cuentas.
CREATE OR REPLACE FUNCTION public.iris_revoke_invite(p_id uuid)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  inv app_invites%ROWTYPE;
BEGIN
  SELECT * INTO inv FROM app_invites WHERE id = p_id;
  IF NOT FOUND OR NOT (inv.created_by = auth.uid() OR public.is_app_admin()) THEN
    RAISE EXCEPTION 'IRIS_INVITE_FORBIDDEN';
  END IF;
  UPDATE app_invites SET revoked_at = COALESCE(revoked_at, now())
  WHERE id = p_id;
  IF inv.email IS NOT NULL AND inv.project_id IS NOT NULL THEN
    DELETE FROM project_invitations
    WHERE project_id = inv.project_id AND lower(email) = lower(inv.email)
      AND accepted_at IS NULL;
  END IF;
END;
$$;

REVOKE ALL ON FUNCTION public.iris_revoke_invite(uuid) FROM public, anon;
GRANT EXECUTE ON FUNCTION public.iris_revoke_invite(uuid) TO authenticated;

-- ─── Comprobar ─────────────────────────────────────────────────────────────
-- Debe devolver tu cuenta con plan «tester» y 3 funciones.
SELECT u.email, a.role, a.status, a.plan,
  (SELECT count(*) FROM pg_proc WHERE proname IN (
     'iris_create_invite', 'iris_redeem_invite', 'iris_revoke_invite'))
    AS funciones
FROM public.app_access a JOIN auth.users u ON u.id = a.user_id
WHERE a.role = 'admin';
