-- =====================================================================
-- FASE 2: Triggers para generaci�n de folio, matriz SLA e impacto/urgencia
-- Ejecutable en SQL Editor de Supabase. Idempotente.
-- =====================================================================

-- =========================
-- 1) Funci�n: generar folio
-- =========================
CREATE OR REPLACE FUNCTION public.trg_generar_folio()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = public
AS $$
DECLARE
  v_year       INTEGER;
  v_fecha_mty  TIMESTAMP WITH TIME ZONE;
  v_lock_key   BIGINT;
  v_correl     INTEGER;
  v_folio_new  VARCHAR(20);
BEGIN
  IF NEW.folio IS NOT NULL AND trim(NEW.folio) <> '' THEN
    RETURN NEW;
  END IF;

  v_fecha_mty := COALESCE(NEW.created_at, now()) AT TIME ZONE 'America/Monterrey';
  v_year      := EXTRACT(YEAR FROM v_fecha_mty);

  v_lock_key := hashtextextended(v_year::text, 131542391);
  PERFORM pg_advisory_xact_lock(v_lock_key);

  SELECT COALESCE(MAX((substring(folio from 'TECNM-' || v_year || '-(.*)$'))::INTEGER), 0) + 1
    INTO v_correl
  FROM public.tickets
  WHERE folio LIKE 'TECNM-' || v_year || '-%';

  v_folio_new := 'TECNM-' || v_year || '-' || lpad(v_correl::text, 4, '0');
  NEW.folio := v_folio_new;
  RETURN NEW;
END;
$$;

-- =========================
-- 2) Funci�n: calcular SLA por matriz urgencia/impacto
-- =========================
CREATE OR REPLACE FUNCTION public.trg_calcular_sla()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = public
AS $$
DECLARE
  v_urg        text;
  v_imp        text;
  v_prioridad  varchar(50);
  v_sla_id     uuid;
  v_horas_res  integer;
  v_created_at timestamptz;
BEGIN
  v_urg := upper(NEW.urgencia::text);
  v_imp := upper(NEW.impacto::text);

  IF v_urg = 'ALTA' AND v_imp = 'ALTO' THEN
    v_prioridad := 'Cr�tica';
  ELSIF v_urg = 'ALTA' AND v_imp = 'MEDIO' THEN
    v_prioridad := 'Alta';
  ELSIF v_urg = 'ALTA' AND v_imp = 'BAJO' THEN
    v_prioridad := 'Media';
  ELSIF v_urg = 'MEDIA' AND v_imp = 'ALTO' THEN
    v_prioridad := 'Alta';
  ELSIF v_urg = 'MEDIA' AND v_imp = 'MEDIO' THEN
    v_prioridad := 'Media';
  ELSIF v_urg = 'MEDIA' AND v_imp = 'BAJO' THEN
    v_prioridad := 'Baja';
  ELSIF v_urg = 'BAJA' AND v_imp = 'ALTO' THEN
    v_prioridad := 'Media';
  ELSIF v_urg = 'BAJA' AND v_imp = 'MEDIO' THEN
    v_prioridad := 'Baja';
  ELSIF v_urg = 'BAJA' AND v_imp = 'BAJO' THEN
    v_prioridad := 'Baja';
  ELSE
    RAISE EXCEPTION 'Valores de urgencia/impacto no reconocidos. urgencia=%, impacto=%', NEW.urgencia, NEW.impacto;
  END IF;

  SELECT id, horas_resolucion
    INTO v_sla_id, v_horas_res
  FROM public.sla_priorities
  WHERE lower(nombre) = lower(v_prioridad)
    AND activo = true
  LIMIT 1;

  IF v_sla_id IS NULL THEN
    RAISE EXCEPTION 'No existe sla_priority activo con nombre "%". Verifica tabla sla_priorities.', v_prioridad;
  END IF;

  NEW.sla_priority_id := v_sla_id;

  v_created_at := COALESCE(NEW.created_at, now());
  NEW.fecha_limite := v_created_at + (v_horas_res * interval '1 hour');

  RETURN NEW;
END;
$$;

-- =========================
-- 3) Triggers
-- =========================
DROP TRIGGER IF EXISTS trg_tickets_before_insert_folio ON public.tickets;
CREATE TRIGGER trg_tickets_before_insert_folio
BEFORE INSERT ON public.tickets
FOR EACH ROW
EXECUTE FUNCTION public.trg_generar_folio();

DROP TRIGGER IF EXISTS trg_tickets_before_insert_sla ON public.tickets;
CREATE TRIGGER trg_tickets_before_insert_sla
BEFORE INSERT ON public.tickets
FOR EACH ROW
EXECUTE FUNCTION public.trg_calcular_sla();

DROP TRIGGER IF EXISTS trg_tickets_before_update_sla ON public.tickets;
CREATE TRIGGER trg_tickets_before_update_sla
BEFORE UPDATE OF urgencia, impacto ON public.tickets
FOR EACH ROW
WHEN (OLD.urgencia IS DISTINCT FROM NEW.urgencia OR OLD.impacto IS DISTINCT FROM NEW.impacto)
EXECUTE FUNCTION public.trg_calcular_sla();
