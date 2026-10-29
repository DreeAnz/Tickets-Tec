-- =====================================================================
-- FASE 2: Script de prueba
-- =====================================================================

-- 1) Crear usuario de prueba (Solicitante)
WITH rol AS (
  SELECT id FROM public.roles WHERE lower(nombre) = lower('Solicitante') LIMIT 1
),
loc AS (
  SELECT id FROM public.locations WHERE codigo = ''TNM-MTY'' OR lower(nombre) LIKE ''%tnm%mty%'' LIMIT 1
)
INSERT INTO public.users (id, auth_id, email, nombre_completo, numero_empleado, telefono, role_id, location_id, activo, created_at, updated_at)
SELECT
  gen_random_uuid(),
  gen_random_uuid(),
  ''test.fase2.'' || extract(epoch from now())::bigint || ''@tecnm.test'',
  ''Usuario Prueba Fase 2'',
  ''EMP-TEST-F2'',
  ''8110000000'',
  rol.id,
  loc.id,
  true,
  now(),
  now()
FROM rol, loc
ON CONFLICT DO NOTHING;

-- 2) Insertar 3 tickets
WITH u AS (
  SELECT id AS user_id FROM public.users WHERE email LIKE ''test.fase2.%'' ORDER BY created_at DESC LIMIT 1
),
loc AS (
  SELECT id AS location_id FROM public.locations WHERE codigo = ''TNM-MTY'' OR lower(nombre) LIKE ''%tnm%mty%'' LIMIT 1
),
cat AS (
  SELECT id AS category_id FROM public.service_categories WHERE lower(nombre) = ''laptop'' LIMIT 1
)
INSERT INTO public.tickets (
  id, folio, titulo, descripcion, service_type, status,
  urgencia, impacto,
  solicitante_id, location_id, category_id,
  created_at, updated_at
)
SELECT gen_random_uuid(), '''', ''F2 Test - Alta/Alto'', ''Prueba matriz SLA Alta/Alto'', ''INCIDENTE'', ''REGISTRADO'', ''ALTA''::"UrgencyLevel", ''ALTO''::"ImpactLevel", u.user_id, loc.location_id, cat.category_id, now(), now() FROM u, loc, cat
UNION ALL
SELECT gen_random_uuid(), '''', ''F2 Test - Media/Medio'', ''Prueba matriz SLA Media/Medio'', ''INCIDENTE'', ''REGISTRADO'', ''MEDIA''::"UrgencyLevel", ''MEDIO''::"ImpactLevel", u.user_id, loc.location_id, cat.category_id, now(), now() FROM u, loc, cat
UNION ALL
SELECT gen_random_uuid(), '''', ''F2 Test - Baja/Bajo'', ''Prueba matriz SLA Baja/Bajo'', ''INCIDENTE'', ''REGISTRADO'', ''BAJA''::"UrgencyLevel", ''BAJO''::"ImpactLevel", u.user_id, loc.location_id, cat.category_id, now(), now() FROM u, loc, cat;

-- 3) Verificacion
SELECT t.folio, sp.nombre AS prioridad, sp.horas_resolucion, t.created_at, t.fecha_limite, (t.fecha_limite - t.created_at) AS diferencia
FROM public.tickets t
LEFT JOIN public.sla_priorities sp ON sp.id = t.sla_priority_id
WHERE t.titulo LIKE ''F2 Test - %''
ORDER BY t.created_at ASC;

-- LIMPIEZA COMENTADA
-- DELETE FROM public.tickets WHERE titulo LIKE ''F2 Test - %'';
-- DELETE FROM public.users WHERE email LIKE ''test.fase2.%'';
