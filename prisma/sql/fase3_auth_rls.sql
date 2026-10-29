-- =====================================================================
-- FASE 3: Sincronización Supabase Auth -> public.users + Políticas RLS
-- Ejecutable en SQL Editor de Supabase. Idempotente.
-- =====================================================================

-- =========================
-- 1) Verificación de rol base
-- =========================
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.roles WHERE nombre = 'Solicitante') THEN
    RAISE EXCEPTION 'Rol Solicitante no encontrado. Ejecuta primero el seed de Prisma.';
  END IF;
END;
$$;

-- =========================
-- 2) Trigger A: sincronizar ALTA de usuario (auth.users -> public.users)
--    Asigna el rol por defecto "Solicitante".
-- =========================
CREATE OR REPLACE FUNCTION public.trg_sincronizar_usuario()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_role_id         uuid;
  v_email           varchar(150);
  v_nombre_completo varchar(200);
BEGIN
  v_email := LEFT(trim(NEW.email), 150);

  v_nombre_completo := COALESCE(
    NEW.raw_user_meta_data->>'nombre_completo',
    NEW.raw_user_meta_data->>'full_name',
    NEW.raw_user_meta_data->>'name',
    split_part(NEW.email, '@', 1),
    'Usuario'
  );
  v_nombre_completo := LEFT(v_nombre_completo, 200);

  -- Rol por defecto: Solicitante
  SELECT id INTO v_role_id FROM public.roles WHERE nombre = 'Solicitante' LIMIT 1;

  INSERT INTO public.users (auth_id, email, nombre_completo, role_id)
  VALUES (NEW.id, v_email, v_nombre_completo, v_role_id)
  ON CONFLICT (auth_id) DO NOTHING
  ON CONFLICT (email) DO NOTHING;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_on_auth_user_created ON auth.users;
CREATE TRIGGER trg_on_auth_user_created
AFTER INSERT ON auth.users
FOR EACH ROW EXECUTE FUNCTION public.trg_sincronizar_usuario();

-- =========================
-- 3) Trigger B: sincronizar CAMBIOS (email / nombre) en auth.users
-- =========================
CREATE OR REPLACE FUNCTION public.trg_sincronizar_usuario_actualizado()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_email    varchar(150) := LEFT(trim(NEW.email), 150);
  v_nombre   varchar(200);
  v_existe   uuid;
BEGIN
  IF OLD.id <> NEW.id THEN
    DELETE FROM public.users WHERE auth_id = OLD.id;
  END IF;

  v_nombre := COALESCE(
    NEW.raw_user_meta_data->>'nombre_completo',
    NEW.raw_user_meta_data->>'full_name',
    NEW.raw_user_meta_data->>'name',
    split_part(NEW.email, '@', 1),
    'Usuario'
  );

  SELECT id INTO v_existe FROM public.users WHERE auth_id = NEW.id;

  IF v_existe IS NULL THEN
    -- Usuario creado antes de instalar el trigger: se reincorpora aquí.
    INSERT INTO public.users (auth_id, email, nombre_completo, role_id)
    VALUES (
      NEW.id,
      v_email,
      LEFT(v_nombre, 200),
      (SELECT id FROM public.roles WHERE nombre = 'Solicitante' LIMIT 1)
    )
    ON CONFLICT (auth_id) DO NOTHING
    ON CONFLICT (email) DO NOTHING;
    RETURN NEW;
  END IF;

  UPDATE public.users
     SET email           = v_email,
         nombre_completo = LEFT(v_nombre, 200),
         updated_at      = now()
   WHERE auth_id = NEW.id;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_on_auth_user_updated ON auth.users;
CREATE TRIGGER trg_on_auth_user_updated
AFTER UPDATE ON auth.users
FOR EACH ROW EXECUTE FUNCTION public.trg_sincronizar_usuario_actualizado();

-- =========================
-- 4) Trigger C: sincronizar BAJA (auth.users -> public.users)
-- =========================
CREATE OR REPLACE FUNCTION public.trg_sincronizar_usuario_eliminado()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  DELETE FROM public.users WHERE auth_id = OLD.id;
  RETURN OLD;
END;
$$;

DROP TRIGGER IF EXISTS trg_on_auth_user_deleted ON auth.users;
CREATE TRIGGER trg_on_auth_user_deleted
AFTER DELETE ON auth.users
FOR EACH ROW EXECUTE FUNCTION public.trg_sincronizar_usuario_eliminado();

-- =====================================================================================
-- 5) Funciones auxiliares para políticas RLS
-- =====================================================================================

-- ID del usuario (public.users) del usuario autenticado actual
CREATE OR REPLACE FUNCTION public.fn_tnm_user_id()
RETURNS uuid
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT id FROM public.users WHERE auth_id = auth.uid() AND activo LIMIT 1;
$$;

-- Nombre del rol del usuario autenticado actual
CREATE OR REPLACE FUNCTION public.fn_tnm_user_role()
RETURNS varchar(50)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT r.nombre
    FROM public.users u
    JOIN public.roles r ON r.id = u.role_id
   WHERE u.auth_id = auth.uid()
     AND u.activo
   LIMIT 1;
$$;

-- ¿Es staff? (Técnico, Gestor de Tickets o Administrador)
CREATE OR REPLACE FUNCTION public.fn_tnm_is_staff()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT public.fn_tnm_user_role() IN ('Técnico', 'Gestor de Tickets', 'Administrador');
$$;

-- =========================
-- 6) Habilitar RLS en tablas públicas
-- =========================
ALTER TABLE public.roles                ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.users                ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.locations            ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.service_categories   ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sla_priorities       ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tickets              ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.status_history       ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.satisfaction_surveys ENABLE ROW LEVEL SECURITY;

-- =========================
-- 7) Políticas RLS
-- Nota: Prisma se conecta con el rol dueño de la BD (postgres) y NO pasa por RLS
--       (bypass rls). Estas políticas restauran el filtrado por usuario para los
--       clientes de Supabase con la anon key (PostgREST) — seguridad de perímetro.
-- =========================

-- ---------- USUARIOS ----------
DROP POLICY IF EXISTS "users: leer propio o staff" ON public.users;
CREATE POLICY "users: leer propio o staff" ON public.users
  FOR SELECT
  USING (auth_id = auth.uid() OR public.fn_tnm_is_staff());

-- El usuario solo puede actualizar SUS datos; su rol queda fijo.
DROP POLICY IF EXISTS "users: actualizar datos propios" ON public.users;
CREATE POLICY "users: actualizar datos propios" ON public.users
  FOR UPDATE
  USING (auth_id = auth.uid())
  WITH CHECK (
    auth_id = auth.uid()
    AND role_id = (SELECT role_id FROM public.users u WHERE u.auth_id = auth.uid())
  );

-- ---------- UBICACIONES / CATEGORÍAS / SLA (catálogos: lectura general) ----------
DROP POLICY IF EXISTS "catalogos: lectura autenticada" ON public.locations;
CREATE POLICY "catalogos: lectura autenticada" ON public.locations
  FOR SELECT USING (auth.role() = 'authenticated' OR activo);

DROP POLICY IF EXISTS "catalogos: lectura autenticada" ON public.service_categories;
CREATE POLICY "catalogos: lectura autenticada" ON public.service_categories
  FOR SELECT USING (auth.role() = 'authenticated' OR activo);

DROP POLICY IF EXISTS "catalogos: lectura autenticada" ON public.sla_priorities;
CREATE POLICY "catalogos: lectura autenticada" ON public.sla_priorities
  FOR SELECT USING (auth.role() = 'authenticated' OR activo);

DROP POLICY IF EXISTS "catalogos: lectura" ON public.roles;
CREATE POLICY "catalogos: lectura" ON public.roles
  FOR SELECT USING (auth.uid() IS NOT NULL);

-- ---------- TICKETS ----------
-- Solicitante: ve SUS tickets; staff ve TODOS
DROP POLICY IF EXISTS "tickets: solicitante ve propios, staff ve todos" ON public.tickets;
CREATE POLICY "tickets: solicitante ve propios, staff ve todos" ON public.tickets
  FOR SELECT
  USING (solicitante_id = public.fn_tnm_user_id() OR public.fn_tnm_is_staff());

-- Solicitante: solo puede crear tickets asignándose a sí mismo
DROP POLICY IF EXISTS "tickets: solicitante crea propios" ON public.tickets;
CREATE POLICY "tickets: solicitante crea propios" ON public.tickets
  FOR INSERT
  WITH CHECK (
    solicitante_id = public.fn_tnm_user_id()
    AND tecnico_id IS NULL
    AND status = 'REGISTRADO'
  );

-- Staff: puede crear tickets en nombre de cualquier solicitante (walk-in)
DROP POLICY IF EXISTS "tickets: staff crea" ON public.tickets;
CREATE POLICY "tickets: staff crea" ON public.tickets
  FOR INSERT
  WITH CHECK (public.fn_tnm_is_staff());

-- Solicitante: puede cancelar (REGISTRADO -> CERRADO) su propio ticket
DROP POLICY IF EXISTS "tickets: solicitante cancela el suyo" ON public.tickets;
CREATE POLICY "tickets: solicitante cancela el suyo" ON public.tickets
  FOR UPDATE
  USING (solicitante_id = public.fn_tnm_user_id() AND status = 'REGISTRADO')
  WITH CHECK (
    solicitante_id = public.fn_tnm_user_id()
    AND status = 'CERRADO'
    AND tecnico_id IS NULL
  );

-- Staff: puede actualizar cualquier ticket
DROP POLICY IF EXISTS "tickets: staff actualiza" ON public.tickets;
CREATE POLICY "tickets: staff actualiza" ON public.tickets
  FOR UPDATE
  USING (public.fn_tnm_is_staff());

-- Baja de tickets: solo Administrador
DROP POLICY IF EXISTS "tickets: administración elimina" ON public.tickets;
CREATE POLICY "tickets: administración elimina" ON public.tickets
  FOR DELETE
  USING (public.fn_tnm_user_role() = 'Administrador');

-- ---------- HISTORIAL DE ESTADOS ----------
-- El propio usuario consulta el auditoría de sus tickets; staff accede a todo.
DROP POLICY IF EXISTS "status_history: leer por ticket visible" ON public.status_history;
CREATE POLICY "status_history: leer por ticket visible" ON public.status_history
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.tickets t
       WHERE t.id = status_history.ticket_id
         AND (t.solicitante_id = public.fn_tnm_user_id() OR public.fn_tnm_is_staff())
    )
  );

-- Los cambios de estado los ejecuta la app vía Prisma (service role / postgres).
-- Con PostgREST directo, solo staff puede insertar auditoría explícita:
DROP POLICY IF EXISTS "status_history: staff inserta" ON public.status_history;
CREATE POLICY "status_history: staff inserta" ON public.status_history
  FOR INSERT
  WITH CHECK (public.fn_tnm_is_staff());

-- ---------- ENCUESTAS (CSAT) ----------
-- Se crea por el propio usuario sobre SU ticket resuelto/cerrado
DROP POLICY IF EXISTS "surveys: solo el evaluador" ON public.satisfaction_surveys;
CREATE POLICY "surveys: solo el evaluador" ON public.satisfaction_surveys
  FOR SELECT
  USING (
    evaluador_id = public.fn_tnm_user_id()
    OR public.fn_tnm_is_staff()
  );

DROP POLICY IF EXISTS "surveys: evalúa su ticket" ON public.satisfaction_surveys;
CREATE POLICY "surveys: evalúa su ticket" ON public.satisfaction_surveys
  FOR INSERT
  WITH CHECK (
    evaluador_id = public.fn_tnm_user_id()
    AND EXISTS (
      SELECT 1 FROM public.tickets t
       WHERE t.id = satisfaction_surveys.ticket_id
         AND t.solicitante_id = public.fn_tnm_user_id()
         AND t.status IN ('RESUELTO', 'CERRADO')
    )
    AND calificacion BETWEEN 1 AND 5
  );

DROP POLICY IF EXISTS "surveys: staff edita" ON public.satisfaction_surveys;
CREATE POLICY "surveys: staff edita" ON public.satisfaction_surveys
  FOR UPDATE
  USING (public.fn_tnm_is_staff());

-- =========================
-- 8) Reconciliar usuarios existentes
--    (users creados con el SQL Editor antes de instalar los triggers)
-- =========================
-- Nota: si ejecutaste signup ANTES de correr este script, descomenta:
-- INSERT INTO public.users (auth_id, email, nombre_completo, role_id)
-- SELECT u.id,
--        LEFT(trim(u.email), 150),
--        LEFT(COALESCE(u.raw_user_meta_data->>'nombre_completo',
--                      u.raw_user_meta_data->>'full_name',
--                      split_part(u.email, '@', 1), 'Usuario'), 200),
--        (SELECT id FROM public.roles WHERE nombre = 'Solicitante' LIMIT 1)
--   FROM auth.users u
--   WHERE NOT EXISTS (SELECT 1 FROM public.users p WHERE p.auth_id = u.id)
-- ON CONFLICT DO NOTHING;
