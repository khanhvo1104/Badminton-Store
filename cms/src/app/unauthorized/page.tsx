import Link from "next/link";

import { SiteShell } from "@/components/layout/site-shell";
import { logout } from "@/features/auth/actions/logout";
import { ConfigurationUnavailableShell } from "@/features/landing/components/configuration-unavailable-shell";
import { CMS_DASHBOARD_PATH, CMS_LOGIN_PATH } from "@/lib/auth/authorization";
import { getPublicEnvironment } from "@/lib/env/public-env";
import { isPublicEnvironmentError } from "@/lib/errors/public-environment-error";

export default function UnauthorizedPage() {
  try {
    getPublicEnvironment();
  } catch (error) {
    if (isPublicEnvironmentError(error)) {
      return <ConfigurationUnavailableShell />;
    }

    throw error;
  }

  return (
    <SiteShell>
      <main
        id="main-content"
        className="mx-auto flex min-h-screen max-w-4xl items-center px-6 py-16"
      >
        <section className="w-full rounded-3xl border border-white/10 bg-slate-900/80 p-8 shadow-2xl shadow-slate-950/30 sm:p-12">
          <p className="text-sm font-semibold uppercase tracking-[0.3em] text-emerald-300">
            Access restricted
          </p>
          <h1 className="mt-4 text-4xl font-semibold tracking-tight text-white">
            You can&apos;t access this CMS area.
          </h1>
          <p className="mt-4 max-w-2xl text-base leading-7 text-slate-200">
            This CMS is available only to approved active staff accounts.
          </p>

          <div className="mt-8 flex flex-wrap gap-4">
            <Link
              href={CMS_LOGIN_PATH}
              className="rounded-full bg-emerald-300 px-5 py-3 text-sm font-semibold text-slate-950 transition hover:bg-emerald-200 focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-emerald-200"
            >
              Back to sign in
            </Link>
            <Link
              href={CMS_DASHBOARD_PATH}
              className="rounded-full border border-white/15 px-5 py-3 text-sm font-semibold text-white transition hover:border-white/30 hover:bg-white/5 focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-emerald-200"
            >
              Retry dashboard
            </Link>
          </div>

          <form action={logout} className="mt-6">
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
