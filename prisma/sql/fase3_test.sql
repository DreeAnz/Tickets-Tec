-- =====================================================================
-- FASE 3: Script de prueba/manual de verificación (SQL Editor de Supabase)
-- =====================================================================

-- 1) Confirmar triggers instalados sobre auth.users
SELECT tgname, tgtable_name
  FROM pg_trigger
 WHERE tgrelid = 'auth.users'::regclass
   AND NOT tgisinternal
 ORDER BY tgname;

-- 2) Confirmar funciones de sincronización
SELECT proname
  FROM pg_proc
 WHERE proname IN (
   'trg_sincronizar_usuario',
   'trg_sincronizar_usuario_actualizado',
   'trg_sincronizar_usuario_eliminado'
 );

-- 3) Confirmar funciones auxiliares de RLS
SELECT proname
  FROM pg_proc
 WHERE proname IN ('fn_tnm_user_id', 'fn_tnm_user_role', 'fn_tnm_is_staff');

-- 4) Confirmar que RLS está ACTIVADO en las 8 tablas
--    (rls_enabled debe ser TRUE / 't')
SELECT relname AS tabla, relrowsecurity AS rls_enabled
  FROM pg_class
 WHERE relname IN (
   'roles', 'users', 'locations', 'service_categories',
   'sla_priorities', 'tickets', 'status_history', 'satisfaction_surveys'
 )
   AND relnamespace = 'public'::regnamespace;

-- 5) Listar políticas creadas (deben aparecer ~14 políticas)
SELECT tablename, policyname, cmd
  FROM pg_policies
 WHERE schemaname = 'public'
 ORDER BY tablename, policyname;

-- =====================================================================
-- PRUEBA DEL CHECKPOINT (create transport vía SQL):
-- Crear un usuario "sintético" en auth.users simulando un signup.
-- El trigger trg_on_auth_user_created debe insertarlo en public.users
-- con rol Solicitante automáticamente.
-- =====================================================================
DO $$
DECLARE
  v_auth_id uuid;
  v_user_id uuid;
  v_role    varchar(50);
BEGIN
  -- Crear usuario de prueba
  INSERT INTO auth.users (
    instance_id, id, aud, role, email,
    encrypted_password, email_confirmed_at, created_at, updated_at,
    raw_user_meta_data, raw_app_meta_data
  ) VALUES (
    '00000000-0000-0000-0000-000000000000',
    gen_random_uuid(),
    'authenticated', 'authenticated',
    'prueba.fase3.@tecnm.mx',
    crypt('ClavePruebaFase3-2026!', 'bf'),
    now(), now(), now(),
    '{"nombre_completo": "Usuario Prueba Fase 3"}'::jsonb,
    '{"provider": "email", "providers": ["email"]}'::jsonb
  )
  RETURNING id INTO v_auth_id;

  -- Verifica: la fila sincronizada debe existir
  SELECT p.id, r.nombre INTO v_user_id, v_role
    FROM public.users p
    JOIN public.roles r ON r.id = p.role_id
   WHERE p.auth_id = v_auth_id;

  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'FALLO: el trigger no sincronizó el usuario en public.users';
  END IF;

  RAISE NOTICE 'OK usuario sincronizado: auth_id=% | users.id=% | rol=%', v_auth_id, v_user_id, v_role;

  -- El rol debe ser 'Solicitante'
  IF v_role <> 'Solicitante' THEN
    RAISE EXCEPTION 'FALLO: rol esperado Solicitante, obtenido %', v_role;
  END IF;

  -- Limpieza del usuario de prueba (dispara el trigger de borrado)
  DELETE FROM auth.users WHERE id = v_auth_id;

  IF EXISTS (SELECT 1 FROM public.users WHERE auth_id = v_auth_id) THEN
    RAISE EXCEPTION 'FALLO: el trigger de borrado no eliminó la fila de public.users';
  END IF;

  RAISE NOTICE 'OK borrado sincronizado: public.users quedó limpio';
END;
$$;
