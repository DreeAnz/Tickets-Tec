import { NextResponse } from "next/server";
import { createSupabaseServerClient } from "@/lib/supabase/server";

export async function GET(request: Request) {
  const { searchParams, origin } = new URL(request.url);
  const code = searchParams.get("code");
  const next = searchParams.get("next") ?? "/dashboard";

  if (code) {
    const supabase = await createSupabaseServerClient();
    const { error } = await supabase.auth.exchangeCodeForSession(code);

    if (!error) {
      const forwardedHost = request.headers.get("x-forwarded-host");
      const forwardedProto = request.headers.get("x-forwarded-proto");
      const url = new URL(next, origin);

      if (forwardedHost) {
        url.protocol = forwardedProto ?? "https";
        url.host = forwardedHost;
      }

      return NextResponse.redirect(url);
    }
  }

  return NextResponse.redirect(new URL("/login?error=callback", origin));
}
