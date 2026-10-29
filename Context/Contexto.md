Actúa como un Desarrollador Full-Stack Senior y Arquitecto de Software. Tu objetivo es guiarme y construir paso a paso el "Sistema Web de Gestión de Tickets de Mantenimiento para el TecNM" utilizando la siguiente pila tecnológica:

- **Frontend:** Next.js (App Router, Server Components y Server Actions)
- **Base de Datos & Auth:** Supabase (PostgreSQL + Supabase Auth + RLS)
- **ORM:** Prisma
- **Despliegue / CI-CD:** Vercel

---

### ⚠️ REGLAS Y METODOLOGÍA DE TRABAJO (STRICT WORKFLOW)
1. **Desarrollo por Fases Finas:** Trabajaremos estricta y únicamente **UNA FASE A LA VEZ**.
2. **Sin Saltos de Fase:** Queda estrictamente prohibido avanzar a la siguiente fase o escribir código de fases posteriores sin validar completamente la actual.
3. **Criterios de Aceptación y Checkpoint:** Al finalizar cada fase, debes proporcionarme:
   - Los archivos creados o modificados con su código completo y limpio.
   - Las pruebas puntuales (Checkpoints) que debo ejecutar localmente o en el entorno para verificar la funcionalidad.
   - La indicación explícita de esperar mi confirmación (`"FASE X VALIDADA"`) antes de proceder con la Fase X+1.

---

### 📋 ROADMAP DE IMPLEMENTACIÓN POR FASES

#### FASE 1: Configuración del Entorno, Prisma Schema y Sembrado (Seed)
* **Objetivo:** Inicializar la arquitectura base, configurar la base de datos PostgreSQL en Supabase y definir el esquema con Prisma ORM[cite: 1, 2].
* **Entregables:**
  1. Configuración de variables de entorno (`.env.local` para Prisma y Supabase).
  2. Archivo `schema.prisma` mapeando los modelos ITIL v3: `Role`, `User`, `Location`, `ServiceCategory`, `SlaPriority`, `Ticket`, `StatusHistory`, y `SatisfactionSurvey`[cite: 2].
  3. Relaciones completas entre modelos y uso de Enums PostgreSQL (`ServiceType`, `TicketStatus`, `UrgencyLevel`, `ImpactLevel`)[cite: 2].
  4. Script de sembrado de datos (`prisma/seed.ts`) con los datos base para roles (`Solicitante`, `Técnico`, `Gestor de Tickets`), prioridades SLA y categorías iniciales[cite: 2].
* **Checkpoint de Cierre:** Ejecución exitosa de `npx prisma db push` o `npx prisma migrate dev` y `npx prisma db seed`, verificando que las tablas y tipos existan correctamente en Supabase[cite: 2].

---

#### FASE 2: Triggers de PostgreSQL en Supabase (Lógica Servidor)
* **Objetivo:** Implementar la lógica de negocio directamente en PostgreSQL utilizando funciones PL/pgSQL y Triggers para automatizar reglas de TI[cite: 2, 3].
* **Entregables:**
  1. **Trigger A (Generación de Folio):** Función que calcule y asigne automáticamente un código correlativo `TECNM-YYYY-XXXX` al insertar un nuevo ticket[cite: 2].
  2. **Trigger B (Matriz SLA e Impacto/Urgencia):** Función que calcule la prioridad (Crítica, Alta, Media, Baja) y la marca de tiempo `fecha_limite` sumando las horas del SLA configurado[cite: 2, 3].
  3. Script de migración SQL ejecutable directamente en el Editor SQL de Supabase para activar estos triggers[cite: 2].
* **Checkpoint de Cierre:** Insertar un registro de prueba desde el Studio de Supabase o Prisma Studio para confirmar que el `folio`, la `prioridad_sla_id` y la `fecha_limite` se autogeneran sin error[cite: 2].

---

#### FASE 3: Autenticación, Integración Supabase Auth y RLS
* **Objetivo:** Configurar la seguridad perimetral, la autenticación de usuarios y las políticas Row Level Security (RLS) en Supabase[cite: 2, 3].
* **Entregables:**
  1. Trigger en Supabase Auth que sincronice automáticamente la creación de un usuario en `auth.users` con la tabla pública `User` (asignando el rol por defecto de "Solicitante")[cite: 2, 3].
  2. Implementación de middleware y cliente de Supabase Auth en Next.js (SSR / Server Components).
  3. Políticas RLS en la base de datos para restringir accesos:
     - **Solicitantes:** Solo ven y crean sus propios tickets[cite: 3].
     - **Técnicos / Gestores:** Acceso completo o filtrado según su área[cite: 3].
* **Checkpoint de Cierre:** Crear un usuario mediante el login/signup de la app, verificar su inserción automática en la tabla pública `User` con el rol por defecto y probar el acceso a rutas protegidas[cite: 2, 3].

---

#### FASE 4: Módulo de Levantamiento de Tickets (Portal del Solicitante)
* **Objetivo:** Construir la interfaz de usuario para la captura e ingresado estandarizado de incidencias y peticiones[cite: 1, 2].
* **Entregables:**
  1. Formulario interactivo en Next.js con validación de tipos y campos (Ubicación, Categoría, Urgencia, Impacto, Título y Descripción)[cite: 2].
  2. Next.js Server Action para procesar la creación del ticket conectando con Prisma ORM[cite: 2].
  3. Vista/Listado de "Mis Solicitudes" para el usuario con indicación de estado en tiempo real (`Registrado`, `Trabajo en Curso`, `Resuelto`, etc.)[cite: 2, 3].
* **Checkpoint de Cierre:** Crear exitosamente un ticket desde el formulario web con una cuenta de rol *Solicitante* y visualizar la tarjeta con el folio correlativo recién generado[cite: 2, 3].

---

#### FASE 5: Consola de Gestión (SPOC), Asignación y Ciclo de Vida ITIL
* **Objetivo:** Construir la consola de administración y control operativo para Gestores de Tickets y Personal Técnico[cite: 1, 2].
* **Entregables:**
  1. Vista de bandeja de entrada/tabla administrativa con filtros (Por estado, categoría, prioridad SLA y ubicación)[cite: 2, 3].
  2. Modal/Acción para la asignación de un técnico a un ticket específico[cite: 3].
  3. Control del flujo de estados (`Registrado` → `Trabajo en Curso` → `Suspendido` → `Resuelto` → `Cerrado`) registrando auditoría en la tabla `StatusHistory`[cite: 3].
* **Checkpoint de Cierre:** Asignar un ticket a un técnico, avanzar su estado a "Resuelto" y comprobar que las marcas de tiempo (`resuelto_at`) e historial de cambios se insertan correctamente[cite: 2, 3].

---

#### FASE 6: Módulo de Evaluación (CSAT) y Dashboard Ejecutivo
* **Objetivo:** Implementar la retroalimentación del usuario final y la consola ejecutiva con KPIs en tiempo real[cite: 1, 2].
* **Entregables:**
  1. Formulario/Componente de encuesta de satisfacción (Escala Likert 1-5 estrellas + comentario) para tickets resueltos[cite: 2, 3].
  2. Dashboard analítico ejecutivo con cálculo de KPIs:
     - Porcentaje de Cumplimiento de SLAs[cite: 1, 2].
     - Tiempo Medio de Resolución (MTTR en horas)[cite: 1, 2].
     - Nivel Promedio de Satisfacción (CSAT)[cite: 2, 3].
* **Checkpoint de Cierre:** Calificar un ticket resuelto y verificar la actualización automática de las métricas en el Dashboard Ejecutivo[cite: 2, 3].

---

#### FASE 7: Despliegue en Vercel, Optimización y Cierre
* **Objetivo:** Preparar el proyecto para producción y desplegar en la infraestructura cloud de Vercel bajo estrategia de Costo Cero[cite: 1, 2].
* **Entregables:**
  1. Configuración del build en Vercel, variables de entorno de producción y scripts de aceleración para Prisma.
  2. Pruebas de estrés ligeras y revisión de políticas de cuota en la capa gratuita de Supabase[cite: 1].
  3. Verificación del pipeline CI/CD ante pushes en el repositorio.
* **Checkpoint de Cierre:** Aplicación 100% funcional en el dominio de Vercel con certificado SSL activo[cite: 1, 2].

---

### 🏁 INSTRUCCIÓN DE INICIO:
Comprendido el roadmap, inicia exclusivamente con la **FASE 1**. Preséntame el archivo `schema.prisma` completo adaptado a los requerimientos, las variables de entorno necesarias y el script de `seed.ts` para ejecutar la inicialización[cite: 2]. No avances a la Fase 2 hasta que me pidas la confirmación y yo valide el Checkpoint 1.