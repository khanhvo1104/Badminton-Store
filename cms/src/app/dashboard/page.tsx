import { redirect } from "next/navigation";

import { SiteShell } from "@/components/layout/site-shell";
import { logout } from "@/features/auth/actions/logout";
import {
  type AuthorizationSupabaseClient,
  authorizeCmsRequest,
  CMS_LOGIN_PATH,
  CMS_UNAUTHORIZED_PATH,
} from "@/lib/auth/authorization";
import { createSupabaseServerClient } from "@/lib/supabase/server";

export const dynamic = "force-dynamic";

export default async function DashboardPage() {
  const supabase = await createSupabaseServerClient();
  const authorization = await authorizeCmsRequest(
    supabase as unknown as AuthorizationSupabaseClient,
  );

  if (authorization.kind === "anonymous") {
    redirect(CMS_LOGIN_PATH);
  }

  if (authorization.kind === "unauthorized") {
    redirect(CMS_UNAUTHORIZED_PATH);
  }

  return (
    <SiteShell>
      <main
        id="main-content"
        className="mx-auto flex min-h-screen max-w-5xl items-center px-6 py-16"
      >
        <section className="w-full rounded-3xl border border-white/10 bg-slate-900/80 p-8 shadow-2xl shadow-slate-950/30 sm:p-12">
          <p className="text-sm font-semibold uppercase tracking-[0.3em] text-emerald-300">
            Protected dashboard
          </p>
          <h1 className="mt-4 text-4xl font-semibold tracking-tight text-white">
            Welcome back
            {authorization.profile.fullName
              ? `, ${authorization.profile.fullName}`
              : ""}
            .
          </h1>
          <p className="mt-4 max-w-2xl text-base leading-7 text-slate-200">
            You are signed in as an active {authorization.profile.role} profile.
          </p>

          <form action={logout} className="mt-8">
            <button
              type="submit"
              className="rounded-full border border-white/15 px-5 py-3 text-sm font-semibold text-white transition hover:border-white/30 hover:bg-white/5 focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-emerald-200"
            >
              Sign out
            </button>
          </form>
        </section>
      </main>
    </SiteShell>
  );
}
