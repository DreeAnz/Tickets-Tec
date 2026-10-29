"use client";

import { useState } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { createSupabaseBrowserClient } from "@/lib/supabase/client";
import styles from "./login.module.css";

export default function LoginPage() {
  const router = useRouter();
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [cargando, setCargando] = useState(false);

  async function handleSubmit(e: React.FormEvent<HTMLFormElement>) {
    e.preventDefault();
    setError(null);
    setCargando(true);

    const supabase = createSupabaseBrowserClient();

    const { error: authError } = await supabase.auth.signInWithPassword({
      email: email.trim(),
      password,
    });

    if (authError) {
      if (authError.message === "Email not confirmed") {
        setError("Confirma tu correo electrónico antes de iniciar sesión.");
      } else if (authError.message === "Invalid login credentials") {
        setError("Credenciales inválidas. Verifica tu correo y contraseña.");
      } else {
        setError(authError.message);
      }
      setCargando(false);
      return;
    }

    router.replace("/dashboard");
    router.refresh();
  }

  return (
    <main className={styles.main}>
      <div className={styles.card}>
        <h1>Iniciar sesión</h1>
        <p className={styles.subtitulo}>
          Sistema de Gestión de Tickets de Mantenimiento · TecNM
        </p>

        <form onSubmit={handleSubmit} className={styles.form}>
          <label htmlFor="email">Correo institucional</label>
          <input
            id="email"
            type="email"
            autoComplete="email"
            placeholder="usuario@tecnm.mx"
            value={email}
            onChange={(e) => setEmail(e.target.value)}
            required
          />

          <label htmlFor="password">Contraseña</label>
          <input
            id="password"
            type="password"
            autoComplete="current-password"
            placeholder="••••••••"
            value={password}
            onChange={(e) => setPassword(e.target.value)}
            required
          />

          {error && <p className={styles.error}>{error}</p>}

          <button type="submit" disabled={cargando}>
            {cargando ? "Entrando…" : "Entrar"}
          </button>
        </form>

        <p className={styles.pie}>
          ¿No tienes cuenta?{" "}
          <Link href="/signup">Regístrate</Link>
        </p>
      </div>
    </main>
  );
}
