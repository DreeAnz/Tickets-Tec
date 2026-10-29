import { redirect } from "next/navigation";
import { createSupabaseServerClient } from "@/lib/supabase/server";
import { prisma } from "@/lib/prisma";

export type SessionProfile = {
  userId: string; // id en public.users
  authId: string; // id en auth.users
  email: string;
  nombreCompleto: string;
  roleNombre: string;
  roleDescripcion: string | null;
};

/**
 * Devuelve la sesión activa + perfil sincronizado en public.users,
 * o null si no hay sesión válida.
 */
export async function getProfile(): Promise<SessionProfile | null> {
  const supabase = await createSupabaseServerClient();

  const {
    data: { user },
  } = await supabase.auth.getUser();

  if (!user) return null;

  const profile = await prisma.user.findUnique({
    where: { authId: user.id },
    include: { role: true },
  });

  // Sin fila en public.users (el trigger de Supabase aún no corrió):
  // se reincorpora aquí como "Solicitante" (fallback resiliente).
  if (!profile) {
    const defaultRole = await prisma.role.findUnique({
      where: { nombre: "Solicitante" },
    });
    if (!defaultRole) return null;

    const created = await prisma.user
      .create({
        data: {
          authId: user.id,
          email: user.email ?? "sin-email@tecnm.mx",
          nombreCompleto:
            ((user.user_metadata?.nombre_completo ??
              user.user_metadata?.full_name) as string | undefined) ??
            user.email?.split("@")[0] ??
            "Usuario",
          roleId: defaultRole.id,
        },
        include: { role: true },
      })
      .catch(() => null);

    if (!created) return null;

    return {
      userId: created.id,
      authId: created.authId,
      email: created.email,
      nombreCompleto: created.nombreCompleto,
      roleNombre: created.role.nombre,
      roleDescripcion: created.role.descripcion,
    };
  }

  if (!profile.activo) return null;

  return {
    userId: profile.id,
    authId: profile.authId,
    email: profile.email,
    nombreCompleto: profile.nombreCompleto,
    roleNombre: profile.role.nombre,
    roleDescripcion: profile.role.descripcion,
  };
}

/**
 * Para Server Components de rutas protegidas: redirige a /login si no hay sesión.
 */
export async function requireProfile(): Promise<SessionProfile> {
  const profile = await getProfile();
  if (!profile) redirect("/login");
  return profile;
}
