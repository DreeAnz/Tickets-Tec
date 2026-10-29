"use client";

import { useState } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { createSupabaseBrowserClient } from "@/lib/supabase/client";
import styles from "./signup.module.css";

export default function SignupPage() {
  const router = useRouter();
  const [nombreCompleto, setNombreCompleto] = useState("");
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [confirmPassword, setConfirmPassword] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [mensaje, setMensaje] = useState<string | null>(null);
  const [cargando, setCargando] = useState(false);

  async function handleSubmit(e: React.FormEvent<HTMLFormElement>) {
    e.preventDefault();
    setError(null);
    setMensaje(null);

    if (password !== confirmPassword) {
      setError("Las contraseñas no coinciden.");
      return;
    }
    if (password.length < 8) {
      setError("La contraseña debe tener al menos 8 caracteres.");
      return;
    }

    setCargando(true);
    const supabase = createSupabaseBrowserClient();

    const { data, error: authError } = await supabase.auth.signUp({
      email: email.trim(),
      password,
      options: {
        emailRedirectTo: `${window.location.origin}/auth/callback`,
        data: {
          // Consumido por el trigger trg_sincronizar_usuario (FASE 3)
          nombre_completo: nombreCompleto.trim(),
        },
      },
    });

    if (authError) {
      if (authError.message.includes("already registered")) {
        setError("Este correo ya está registrado. Inicia sesión.");
      } else {
        setError(authError.message);
      }
      setCargando(false);
      return;
    }

    if (data.session) {
      // Confirmación de email desactivada -> sesión inmediata
      router.replace("/dashboard");
      router.refresh();
      return;
    }

    // Confirmación de email activada
    setMensaje(
      "Cuenta creada. Revisa tu correo para confirmar la cuenta antes de iniciar sesión."
    );
    setCargando(false);
  }

  return (
    <main className={styles.main}>
      <div className={styles.card}>
        <h1>Crear cuenta</h1>
        <p className={styles.subtitulo}>
          Serás registrado con el rol <strong>Solicitante</strong> (rol por defecto).
        </p>

        <form onSubmit={handleSubmit} className={styles.form}>
          <label htmlFor="nombre">Nombre completo</label>
          <input
            id="nombre"
            type="text"
            autoComplete="name"
            placeholder="Nombre Apellido"
            value={nombreCompleto}
            onChange={(e) => setNombreCompleto(e.target.value)}
            required
            minLength={3}
            maxLength={200}
          />

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

          <label htmlFor="password">Contraseña (mínimo 8 caracteres)</label>
          <input
            id="password"
            type="password"
            autoComplete="new-password"
            placeholder="••••••••"
            value={password}
            onChange={(e) => setPassword(e.target.value)}
            required
            minLength={8}
          />

          <label htmlFor="confirm">Confirmar contraseña</label>
          <input
            id="confirm"
            type="password"
            autoComplete="new-password"
            placeholder="••••••••"
            value={confirmPassword}
            onChange={(e) => setConfirmPassword(e.target.value)}
            required
            minLength={8}
          />

          {error && <p className={styles.error}>{error}</p>}
          {mensaje && <p className={styles.mensaje}>{mensaje}</p>}

          <button type="submit" disabled={cargando}>
            {cargando ? "Creando cuenta…" : "Registrarse"}
          </button>
        </form>

        <p className={styles.pie}>
          ¿Ya tienes cuenta?{" "}
          <Link href="/login">Inicia sesión</Link>
        </p>
      </div>
    </main>
  );
}
