import { Suspense } from "react";
import { connection } from "next/server";
import Link from "next/link";
import { requireProfile } from "@/lib/auth";
import { cerrarSesion } from "@/app/actions/auth";
import styles from "./dashboard.module.css";

// Ruta dependiente de sesión. La lectura de sesión toca Date.now()
// (validación de expiración del token de Supabase), que es synchronous IO:
// se excluye del shell prerenderizado con connection() + <Suspense>
// (ver authentication-with-cache-components), se migra a uso cache en fases posteriores.

const DESCRIPCION_ROL: Record<string, string> = {
  Solicitante: "Portal del Solicitante — levantamiento y seguimiento de tickets",
  Técnico: "Bandeja técnica — tickets asignados",
  "Gestor de Tickets": "Consola de gestión (SPOC) — asignación y ciclo de vida",
  Administrador: "Configuración y acceso total",
};

export default function DashboardPage() {
  return (
    <Suspense fallback={<Fallback />}>
      <Dashboard />
    </Suspense>
  );
}

function Fallback() {
  return (
    <main className={styles.main}>
      <header className={styles.header}>
        <div>
          <h1>Cargando sesión…</h1>
        </div>
      </header>
    </main>
  );
}

async function Dashboard() {
  // Detiene el prerendering: todo lo que sigue corre solo con una
  // petición real, donde Date.now() es estable.
  await connection();
  const profile = await requireProfile();

  return (
    <main className={styles.main}>
      <header className={styles.header}>
        <div>
          <span className={styles.badge}>Sesión activa · FASE 3</span>
          <h1>Hola, {profile.nombreCompleto}</h1>
          <p className={styles.email}>{profile.email}</p>
        </div>
        <form action={cerrarSesion}>
          <button type="submit" className={styles.logout}>
            Cerrar sesión
          </button>
        </form>
      </header>

      <section className={styles.grid}>
        <div className={styles.card}>
          <h2>Perfil sincronizado (public.users)</h2>
          <dl className={styles.tabla}>
            <div>
              <dt>ID (public.users)</dt>
              <dd>
                <code>{profile.userId}</code>
              </dd>
            </div>
            <div>
              <dt>auth_id (auth.users)</dt>
              <dd>
                <code>{profile.authId}</code>
              </dd>
            </div>
            <div>
              <dt>Rol asignado</dt>
              <dd>
                <span className={styles.rol}>{profile.roleNombre}</span>
              </dd>
            </div>
            <div>
              <dt>Descripción del rol</dt>
              <dd>{profile.roleDescripcion ?? "—"}</dd>
            </div>
          </dl>
        </div>

        <div className={styles.card}>
          <h2>Acceso según rol</h2>
          <p>
            <strong>{profile.roleNombre}</strong> —{" "}
            {DESCRIPCION_ROL[profile.roleNombre] ?? "Acceso estándar"}
          </p>
          <ul className={styles.lista}>
            <li>
              ✅ Autenticación Supabase Auth (email/password) operativa
            </li>
            <li>
              ✅ Usuario sincronizado automáticamente con{" "}
              <code>public.users</code> (trigger de FASE 3)
            </li>
            <li>
              ✅ Políticas RLS activas en tablas públicas (perímetro PostgREST)
            </li>
            <li>
              🚧 Módulo de tickets (FASE 4): próximamente disponible
            </li>
          </ul>
          <Link href="/" className={styles.link}>
            ← Volver al inicio
          </Link>
        </div>
      </section>
    </main>
  );
}
