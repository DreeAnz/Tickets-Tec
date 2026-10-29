# 🚀 FASE 1: Configuración del Entorno, Prisma Schema y Sembrado (Seed)

Esta fase establece el núcleo de datos del sistema. Aquí definimos la conexión a PostgreSQL en Supabase, modelamos el dominio ITIL v3 con Prisma ORM y sembramos los catálogos base (roles, prioridades SLA, ubicaciones y categorías). **No se escribe código de fases posteriores.**

> **Alcance de la Fase 1:** entorno + esquema + seed. Los triggers de folio/SLA son FASE 2 y la autenticación/RLS es FASE 3.

---

## 📁 1. Creación del Proyecto e Instalación de Dependencias

Si aún no tienes el proyecto, créalo con App Router y TypeScript:

```bash
npx create-next-app@latest tecnm-tickets --typescript --app --eslint --src-dir --import-alias "@/*"
```

Ingresa a la carpeta e instala las dependencias base:

```bash
cd tecnm-tickets
npm install @prisma/client@6 @supabase/supabase-js @supabase/ssr
npm install -D prisma@6 tsx dotenv
```

> ⚠️ **Fijamos Prisma en la línea estable 6.x.** El tag `latest` hoy apunta a un **Prisma 8 RC** cuya CLI ya no acepta `--datasource-provider`, ni `env()` clásico, ni `prisma.seed`; usar 6.x mantiene la metodología de esta fase.

Inicializa Prisma con el proveedor PostgreSQL:

```bash
npx prisma init --datasource-provider postgresql
```

> Esto genera `prisma/schema.prisma`, `prisma.config.ts` y un `.env` de ejemplo. **Conservaremos `.env`** (ver sección 2) y usaremos `prisma.config.ts` (sección 5) en lugar del bloque `prisma` de `package.json`.

---

## 🔐 2. Variables de Entorno (`.env`)

> ⚠️ **Corrección importante:** Prisma CLI lee automáticamente el archivo **`.env`**, NO `.env.local`. Next.js sí lee `.env`, `.env.local` y variantes. Por lo tanto, usaremos **`.env`** como fuente única para que tanto `prisma` (CLI) como Next.js (runtime) encuentren las credenciales.
>
> 🔧 **Prisma 6.19+:** ya **no** carga `.env` automáticamente. Se carga explícitamente con `import "dotenv/config";` en `prisma.config.ts` (por eso instalamos `dotenv`). El script `prisma/seed.ts` también debe iniciar con `import "dotenv/config";`.

Crea/edita el archivo **`.env`** en la raíz del proyecto y reemplaza con tus credenciales reales de Supabase (Project Settings → Database y → API):

```env
# ============================================
# BASE DE DATOS - SUPABASE (PostgreSQL)
# ============================================
# Conexión con POOLER (Transaction pooler, puerto 6543).
# Obligatoria para Prisma en runtime/serverless (Vercel).
# Formato: postgresql://postgres.[PROJECT_REF]:[PASSWORD]@aws-0-[REGION].pooler.supabase.com:6543/postgres
DATABASE_URL="postgresql://postgres.abcdefghijk:TU_PASSWORD_AQUI@aws-0-us-east-1.pooler.supabase.com:6543/postgres?pgbouncer=true&connection_limit=1"

# Conexión DIRECTA (sin pooler). Prisma la usa para migraciones/introspección.
# Formato: postgresql://postgres.[PROJECT_REF]:[PASSWORD]@aws-0-[REGION].pooler.supabase.com:5432/postgres
DIRECT_URL="postgresql://postgres.abcdefghijk:TU_PASSWORD_AQUI@aws-0-us-east-1.pooler.supabase.com:5432/postgres"

# ============================================
# SUPABASE (Cliente JS - Auth + RLS)  → FASE 3
# ============================================
NEXT_PUBLIC_SUPABASE_URL="https://abcdefghijk.supabase.co"
NEXT_PUBLIC_SUPABASE_ANON_KEY="tu-anon-key-publica-aqui"
SUPABASE_SERVICE_ROLE_KEY="tu-service-role-key-privada-aqui"
```

### Notas de conexión Supabase
- **`DATABASE_URL` (pooler, 6543):** se usa en runtime. Lleva `?pgbouncer=true&connection_limit=1`.
- **`DIRECT_URL` (directa, 5432):** Prisma la usa para migraciones (`migrate`/`db push`) porque PgBouncer no soporta sentencias de DDL.
- Si tu proyecto nuevo solo expone IPv6 en la conexión directa, usa el **Session pooler** (puerto 5432) como `DIRECT_URL`.

### `.gitignore`
Asegúrate de que **nunca** se suban secretos. Agrega al `.gitignore` (normalmente ya incluye `.env*.local`):

```gitignore
# variables de entorno
.env
.env*.local
# prisma
/prisma/*.db
```

---

## 🗄️ 3. Archivo `prisma/schema.prisma` (Completo)

Modela el dominio ITIL v3 con enums PostgreSQL nativos, relaciones explícitas, índices y nombres de tabla en snake_case.

```prisma
// =====================================================================
// TECNM - Sistema de Gestión de Tickets de Mantenimiento
// Esquema Prisma - Alineado a ITIL v3
// =====================================================================

generator client {
  provider = "prisma-client-js"
}

datasource db {
  provider  = "postgresql"
  url       = env("DATABASE_URL")
  directUrl = env("DIRECT_URL")
}

// =====================================================================
// ENUMS - Tipos PostgreSQL nativos
// =====================================================================

/// Tipo de servicio ITIL
enum ServiceType {
  INCIDENTE         /// Interrupción no planificada de un servicio
  PETICION_SERVICIO /// Solicitud estándar de servicio
}

/// Estados del ciclo de vida del ticket (ITIL)
enum TicketStatus {
  REGISTRADO
  TRABAJO_EN_CURSO
  SUSPENDIDO
  RESUELTO
  CERRADO
}

/// Nivel de urgencia (qué tan rápido se necesita)
enum UrgencyLevel {
  BAJA
  MEDIA
  ALTA
  CRITICA
}

/// Nivel de impacto (cuántos usuarios/servicios afecta)
enum ImpactLevel {
  BAJO
  MEDIO
  ALTO
  CRITICO
}

// =====================================================================
// MODELOS
// =====================================================================

/// Roles del sistema
model Role {
  id          String   @id @default(uuid()) @db.Uuid
  nombre      String   @unique @db.VarChar(50)
  descripcion String?  @db.VarChar(255)
  createdAt   DateTime @default(now()) @map("created_at")
  updatedAt   DateTime @updatedAt @map("updated_at")

  users User[]

  @@map("roles")
}

/// Usuarios del sistema (sincronizados con Supabase Auth en FASE 3)
model User {
  id             String   @id @default(uuid()) @db.Uuid
  authId         String   @unique @map("auth_id") @db.Uuid // ID de auth.users
  email          String   @unique @db.VarChar(150)
  nombreCompleto String   @map("nombre_completo") @db.VarChar(200)
  numeroEmpleado String?  @unique @map("numero_empleado") @db.VarChar(30)
  telefono       String?  @db.VarChar(20)
  roleId         String   @map("role_id") @db.Uuid
  locationId     String?  @map("location_id") @db.Uuid
  activo         Boolean  @default(true)
  createdAt      DateTime @default(now()) @map("created_at")
  updatedAt      DateTime @updatedAt @map("updated_at")

  role     Role      @relation(fields: [roleId], references: [id])
  location Location? @relation(fields: [locationId], references: [id])

  ticketsSolicitados  Ticket[]             @relation("SolicitanteTickets")
  ticketsAsignados    Ticket[]             @relation("TecnicoTickets")
  statusChanges       StatusHistory[]
  satisfactionSurveys SatisfactionSurvey[]

  @@index([roleId])
  @@map("users")
}

/// Ubicaciones / Sedes del TecNM
model Location {
  id        String   @id @default(uuid()) @db.Uuid
  nombre    String   @unique @db.VarChar(150)
  codigo    String   @unique @db.VarChar(30)
  direccion String?  @db.VarChar(300)
  activo    Boolean  @default(true)
  createdAt DateTime @default(now()) @map("created_at")
  updatedAt DateTime @updatedAt @map("updated_at")

  users   User[]
  tickets Ticket[]

  @@map("locations")
}

/// Categorías de servicio (jerárquicas: categoría padre / subcategoría)
model ServiceCategory {
  id          String   @id @default(uuid()) @db.Uuid
  nombre      String   @unique @db.VarChar(100)
  descripcion String?  @db.VarChar(300)
  parentId    String?  @map("parent_id") @db.Uuid
  activo      Boolean  @default(true)
  createdAt   DateTime @default(now()) @map("created_at")
  updatedAt   DateTime @updatedAt @map("updated_at")

  parent   ServiceCategory?  @relation("CategoryTree", fields: [parentId], references: [id])
  children ServiceCategory[] @relation("CategoryTree")

  tickets Ticket[]

  @@index([parentId])
  @@map("service_categories")
}

/// Matriz SLA - Define tiempos de respuesta y resolución por prioridad
model SlaPriority {
  id              String   @id @default(uuid()) @db.Uuid
  nombre          String   @unique @db.VarChar(50) // Crítica, Alta, Media, Baja
  horasRespuesta  Int      @map("horas_respuesta")
  horasResolucion Int      @map("horas_resolucion")
  color           String?  @db.VarChar(20) // Hex para UI
  orden           Int      @default(0)     // Para ordenamiento
  activo          Boolean  @default(true)
  createdAt       DateTime @default(now()) @map("created_at")
  updatedAt       DateTime @updatedAt @map("updated_at")

  tickets Ticket[]

  @@map("sla_priorities")
}

/// Ticket - Entidad central del sistema
model Ticket {
  id          String       @id @default(uuid()) @db.Uuid
  folio       String       @unique @db.VarChar(20) // TECNM-YYYY-XXXX (autogenerado en FASE 2)
  titulo      String       @db.VarChar(200)
  descripcion String       @db.Text
  serviceType ServiceType  @default(INCIDENTE) @map("service_type")
  status      TicketStatus @default(REGISTRADO)
  urgencia    UrgencyLevel @default(MEDIA)
  impacto     ImpactLevel  @default(MEDIO)

  // Relaciones (FKs)
  solicitanteId String  @map("solicitante_id") @db.Uuid
  tecnicoId     String? @map("tecnico_id") @db.Uuid
  locationId    String  @map("location_id") @db.Uuid
  categoryId    String  @map("category_id") @db.Uuid
  slaPriorityId String? @map("sla_priority_id") @db.Uuid // Asignado por trigger (FASE 2)

  // Fechas clave del ciclo de vida
  fechaLimite DateTime? @map("fecha_limite") // Calculada por trigger (FASE 2)
  resueltoAt  DateTime? @map("resuelto_at")
  cerradoAt   DateTime? @map("cerrado_at")

  // Auditoría
  createdAt DateTime @default(now()) @map("created_at")
  updatedAt DateTime @updatedAt @map("updated_at")

  // Relaciones navegables
  solicitante User            @relation("SolicitanteTickets", fields: [solicitanteId], references: [id])
  tecnico     User?           @relation("TecnicoTickets", fields: [tecnicoId], references: [id])
  location    Location        @relation(fields: [locationId], references: [id])
  category    ServiceCategory @relation(fields: [categoryId], references: [id])
  slaPriority SlaPriority?    @relation(fields: [slaPriorityId], references: [id])

  statusHistory      StatusHistory[]
  satisfactionSurvey SatisfactionSurvey?

  @@index([status])
  @@index([solicitanteId])
  @@index([tecnicoId])
  @@index([slaPriorityId])
  @@index([categoryId])
  @@index([locationId])
  @@index([createdAt])
  @@map("tickets")
}

/// Historial de cambios de estado (Auditoría ITIL)
model StatusHistory {
  id             String       @id @default(uuid()) @db.Uuid
  ticketId       String       @map("ticket_id") @db.Uuid
  estadoAnterior TicketStatus @map("estado_anterior")
  estadoNuevo    TicketStatus @map("estado_nuevo")
  comentario     String?      @db.Text
  cambiadoPor    String       @map("cambiado_por") @db.Uuid
  createdAt      DateTime     @default(now()) @map("created_at")

  ticket  Ticket @relation(fields: [ticketId], references: [id], onDelete: Cascade)
  usuario User   @relation(fields: [cambiadoPor], references: [id])

  @@index([ticketId])
  @@map("status_history")
}

/// Encuesta de satisfacción (CSAT)
model SatisfactionSurvey {
  id           String   @id @default(uuid()) @db.Uuid
  ticketId     String   @unique @map("ticket_id") @db.Uuid
  evaluadorId  String   @map("evaluador_id") @db.Uuid
  calificacion Int      @db.SmallInt // 1-5 estrellas
  comentario   String?  @db.Text
  createdAt    DateTime @default(now()) @map("created_at")

  ticket    Ticket @relation(fields: [ticketId], references: [id], onDelete: Cascade)
  evaluador User   @relation(fields: [evaluadorId], references: [id])

  @@map("satisfaction_surveys")
}
```

---

## 🌱 4. Script de Sembrado `prisma/seed.ts`

Datos base idempotentes (usa `upsert`, por lo que puede ejecutarse varias veces sin duplicar).

```typescript
import 'dotenv/config';
import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

async function main() {
  console.log('🌱 Iniciando sembrado de datos base...\n');

  // ============================================
  // 1. ROLES BASE DEL SISTEMA
  // ============================================
  const roles = [
    { nombre: 'Solicitante', descripcion: 'Usuario final que genera tickets de incidencia o petición' },
    { nombre: 'Técnico', descripcion: 'Personal de TI asignado a resolver tickets' },
    { nombre: 'Gestor de Tickets', descripcion: 'SPOC - asignación, seguimiento y control operativo' },
    { nombre: 'Administrador', descripcion: 'Acceso total al sistema y configuración' },
  ];

  for (const rol of roles) {
    await prisma.role.upsert({
      where: { nombre: rol.nombre },
      update: {},
      create: rol,
    });
  }
  console.log('✅ Roles creados:', roles.map((r) => r.nombre).join(', '));

  // ============================================
  // 2. PRIORIDADES SLA (Matriz de Tiempos)
  // ============================================
  const slaPriorities = [
    { nombre: 'Crítica', horasRespuesta: 1, horasResolucion: 4,  color: '#DC2626', orden: 1 },
    { nombre: 'Alta',    horasRespuesta: 2, horasResolucion: 8,  color: '#EA580C', orden: 2 },
    { nombre: 'Media',   horasRespuesta: 4, horasResolucion: 24, color: '#CA8A04', orden: 3 },
    { nombre: 'Baja',    horasRespuesta: 8, horasResolucion: 72, color: '#16A34A', orden: 4 },
  ];

  for (const sla of slaPriorities) {
    await prisma.slaPriority.upsert({
      where: { nombre: sla.nombre },
      update: sla,
      create: sla,
    });
  }
  console.log('✅ Prioridades SLA creadas:', slaPriorities.map((s) => s.nombre).join(', '));

  // ============================================
  // 3. UBICACIONES (Campus TecNM)
  // ============================================
  const locations = [
    { nombre: 'TecNM Campus México',      codigo: 'TNM-MEX', direccion: 'Av. Universidad 1650, CDMX' },
    { nombre: 'TecNM Campus Guadalajara', codigo: 'TNM-GDL', direccion: 'Av. Vallarta 1125, Jalisco' },
    { nombre: 'TecNM Campus Monterrey',   codigo: 'TNM-MTY', direccion: 'Av. Constitución s/n, NL' },
    { nombre: 'TecNM Campus Puebla',      codigo: 'TNM-PUE', direccion: 'Blvd. Forjadores, Puebla' },
    { nombre: 'TecNM Campus Tijuana',     codigo: 'TNM-TIJ', direccion: 'Av. Tecnológico s/n, BC' },
    { nombre: 'Rectoría General',         codigo: 'TNM-RG',  direccion: 'Av. Universidad 1650, CDMX' },
  ];

  for (const loc of locations) {
    await prisma.location.upsert({
      where: { codigo: loc.codigo },
      update: {},
      create: loc,
    });
  }
  console.log('✅ Ubicaciones creadas:', locations.map((l) => l.codigo).join(', '));

  // ============================================
  // 4. CATEGORÍAS DE SERVICIO (Jerarquía)
  // ============================================
  const categoriasPadre = [
    { nombre: 'Hardware',        descripcion: 'Equipos de cómputo y periféricos' },
    { nombre: 'Software',        descripcion: 'Aplicaciones y licencias' },
    { nombre: 'Redes',           descripcion: 'Conectividad e infraestructura de red' },
    { nombre: 'Infraestructura', descripcion: 'Servidores, energía, climatización' },
    { nombre: 'Soporte Usuario', descripcion: 'Cuentas, accesos y capacitación' },
  ];

  const padresCreados: Record<string, string> = {};
  for (const cat of categoriasPadre) {
    const creada = await prisma.serviceCategory.upsert({
      where: { nombre: cat.nombre },
      update: {},
      create: cat,
    });
    padresCreados[cat.nombre] = creada.id;
  }

  const subcategorias = [
    { nombre: 'Computadora de escritorio', padre: 'Hardware' },
    { nombre: 'Laptop',                    padre: 'Hardware' },
    { nombre: 'Impresora',                 padre: 'Hardware' },
    { nombre: 'Proyector',                 padre: 'Hardware' },
    { nombre: 'Licencias Office',          padre: 'Software' },
    { nombre: 'Antivirus',                 padre: 'Software' },
    { nombre: 'Software académico',        padre: 'Software' },
    { nombre: 'Conectividad WiFi',         padre: 'Redes' },
    { nombre: 'Cableado estructurado',     padre: 'Redes' },
    { nombre: 'Correo institucional',      padre: 'Soporte Usuario' },
    { nombre: 'Plataforma Moodle',         padre: 'Soporte Usuario' },
    { nombre: 'Sistema integral (SAEI)',   padre: 'Soporte Usuario' },
  ];

  for (const sub of subcategorias) {
    await prisma.serviceCategory.upsert({
      where: { nombre: sub.nombre },
      update: { parentId: padresCreados[sub.padre] },
      create: { nombre: sub.nombre, parentId: padresCreados[sub.padre] },
    });
  }
  console.log(
    '✅ Categorías creadas:',
    categoriasPadre.length,
    'padres y',
    subcategorias.length,
    'subcategorías',
  );

  // ============================================
  // RESUMEN FINAL
  // ============================================
  console.log('\n🎉 Sembrado completado exitosamente.\n📊 Resumen:');
  console.log('   - Roles:', await prisma.role.count());
  console.log('   - Prioridades SLA:', await prisma.slaPriority.count());
  console.log('   - Ubicaciones:', await prisma.location.count());
  console.log('   - Categorías:', await prisma.serviceCategory.count());
}

main()
  .catch((e) => {
    console.error('❌ Error durante el sembrado:', e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
```

---

## ⚙️ 5. Configuración de `prisma.config.ts` y `package.json`

En Prisma 6.19 el comando de seed y el datasource se declaran en **`prisma.config.ts`** (generado por `prisma init`), no en `package.json`. Usamos **`tsx`** como runner del seed.

`prisma.config.ts`:

```ts
import 'dotenv/config';
import { defineConfig, env } from 'prisma/config';

export default defineConfig({
  schema: 'prisma/schema.prisma',
  migrations: {
    path: 'prisma/migrations',
    seed: 'tsx prisma/seed.ts',
  },
  engine: 'classic',
  datasource: {
    url: env('DATABASE_URL'),
    directUrl: env('DIRECT_URL'),
  },
});
```

Agrega estos scripts de conveniencia a `package.json`:

```json
{
  "scripts": {
    "db:push": "prisma db push",
    "db:migrate": "prisma migrate dev",
    "db:seed": "prisma db seed",
    "db:studio": "prisma studio"
  }
}
```

---

## ✅ 6. CHECKPOINTS DE VALIDACIÓN (FASE 1)

Ejecuta los comandos **en orden** y valida cada resultado.

### 🔹 Checkpoint 1.0 — Generar el cliente Prisma
```bash
npx prisma generate
```
**Esperado:** `✔ Generated Prisma Client`.

### 🔹 Checkpoint 1.1 — Aplicar el esquema a Supabase
Usa migraciones versionadas (crea la tabla `_prisma_migrations`):
```bash
npx prisma migrate dev --name init
```
> Alternativa rápida sin historial: `npx prisma db push`.
**Esperado:** `Your database is now in sync with your schema.`

### 🔹 Checkpoint 1.2 — Verificar tablas en Supabase
En el **SQL Editor** de Supabase:
```sql
SELECT table_name
FROM information_schema.tables
WHERE table_schema = 'public' AND table_type = 'BASE TABLE'
ORDER BY table_name;
```
**Esperado:** `locations`, `roles`, `satisfaction_surveys`, `service_categories`, `sla_priorities`, `status_history`, `tickets`, `users` y `_prisma_migrations`.

### 🔹 Checkpoint 1.3 — Verificar Enums PostgreSQL
```sql
SELECT t.typname, e.enumlabel
FROM pg_type t
JOIN pg_enum e ON t.oid = e.enumtypid
ORDER BY t.typname, e.enumsortorder;
```
**Esperado:** los 4 enums `ServiceType`, `TicketStatus`, `UrgencyLevel`, `ImpactLevel` con sus valores.

### 🔹 Checkpoint 1.4 — Ejecutar el Seed
```bash
npx prisma db seed
```
**Esperado:**
```
🌱 Iniciando sembrado de datos base...
✅ Roles creados: Solicitante, Técnico, Gestor de Tickets, Administrador
✅ Prioridades SLA creadas: Crítica, Alta, Media, Baja
✅ Ubicaciones creadas: TNM-MEX, TNM-GDL, TNM-MTY, TNM-PUE, TNM-TIJ, TNM-RG
✅ Categorías creadas: 5 padres y 12 subcategorías
🎉 Sembrado completado exitosamente.
📊 Resumen:
   - Roles: 4
   - Prioridades SLA: 4
   - Ubicaciones: 6
   - Categorías: 17
```

### 🔹 Checkpoint 1.5 — Inspección visual con Prisma Studio
```bash
npx prisma studio
```
Abre `http://localhost:5555` y verifica cada modelo con sus datos sembrados.

---

## 🛑 PUNTO DE CONTROL — ESPERANDO CONFIRMACIÓN

**No se avanza a la FASE 2 hasta validar los checkpoints anteriores.**

Ejecuta los 5 checkpoints y responde con:

> **"FASE 1 VALIDADA"**

Si algo falla, compárteme el mensaje de error exacto y lo corregimos antes de continuar. Tras la confirmación, seguimos con la **FASE 2: Triggers de PostgreSQL en Supabase** (folio correlativo `TECNM-YYYY-XXXX` + matriz SLA automática).
