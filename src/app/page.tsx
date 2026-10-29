import Link from "next/link";
import styles from "./page.module.css";

export default function Home() {
  return (
    <div className={styles.page}>
      <main className={styles.main}>
        <span className={styles.kicker}>TecNM · Mantenimiento</span>
        <h1 className={styles.title}>
          Sistema Web de Gestión de Tickets de Mantenimiento
        </h1>
        <p className={styles.desc}>
          Levantamiento de incidencias y peticiones de servicio bajo buenas
          prácticas ITIL v3. Regístrate con tu correo institucional para crear
          y dar seguimiento a tus tickets.
        </p>

        <div className={styles.ctas}>
          <Link href="/login" className={styles.primary}>
            Iniciar sesión
          </Link>
          <Link href="/signup" className={styles.secondary}>
            Crear cuenta
          </Link>
        </div>

        <p className={styles.fase}>
          Fase 3 — Autenticación, Supabase Auth y RLS · Portal Solicitante
          disponible en Fase 4
        </p>
      </main>
    </div>
  );
}
