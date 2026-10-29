import { NextResponse, type NextRequest } from "next/server";
import { createServerClient } from "@supabase/ssr";

const RUTAS_PROTEGIDAS = ["/dashboard", "/tickets", "/gestion", "/admin"];
const RUTAS_DE_AUTH = ["/login", "/signup"];

export async function proxy(request: NextRequest) {
  const { pathname } = request.nextUrl;

  const supabaseResponse = NextResponse.next({ request });

  const supabase = createServerClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
    {
      cookies: {
        getAll() {
          return request.cookies.getAll();
        },
        setAll(cookiesToSet) {
          cookiesToSet.forEach(({ name, value, options }) => {
            request.cookies.set(name, value);
            supabaseResponse.cookies.set(name, value, options);
          });
        },
      },
    }
  );

  // Importante: NO eliminar. getUser() refresca el token vencido
  // y re-emite los cookies de sesión (pattern oficial de @supabase/ssr).
  const {
    data: { user },
  } = await supabase.auth.getUser();

  const tieneSesion = user !== null;
  const esRutaProtegida = RUTAS_PROTEGIDAS.some(
    (r) => pathname === r || pathname.startsWith(r + "/")
  );
  const esRutaDeAuth = RUTAS_DE_AUTH.some((r) => pathname === r);

  // Sin sesión -> rutas protegidas van a /login
  if (!tieneSesion && esRutaProtegida) {
    const url = request.nextUrl.clone();
    url.pathname = "/login";
    url.searchParams.set("next", pathname);
    return NextResponse.redirect(url);
  }

  // Con sesión -> /login y /signup van al dashboard
  if (tieneSesion && esRutaDeAuth) {
    const url = request.nextUrl.clone();
    url.pathname = "/dashboard";
    url.search = "";
    return NextResponse.redirect(url);
  }

  return supabaseResponse;
}

export const config = {
  matcher: [
    // Rutas relevantes; excluye _next/static, _next/image, favicon, etc.
    "/((?!api|_next/static|_next/image|favicon.ico|.*\\.(?:svg|png|jpg|jpeg|gif|webp|ico)$).*)",
  ],
};
