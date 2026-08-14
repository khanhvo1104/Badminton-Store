import { redirect } from "next/navigation";

import { SiteShell } from "@/components/layout/site-shell";
import { UpdatePasswordForm } from "@/features/auth/components/update-password-form";
import { ConfigurationUnavailableShell } from "@/features/landing/components/configuration-unavailable-shell";
import {
  getLoginRedirectPath,
  isVerifiedRecoverySession,
  LOGIN_STATUS_RECOVERY_FAILED,
} from "@/lib/auth/password-recovery";
import { getPublicEnvironment } from "@/lib/env/public-env";
import { isPublicEnvironmentError } from "@/lib/errors/public-environment-error";
import { createSupabaseServerClient } from "@/lib/supabase/server";

export const dynamic = "force-dynamic";

export default async function UpdatePasswordPage() {
  try {
    getPublicEnvironment();
  } catch (error) {
    if (isPublicEnvironmentError(error)) {
      return <ConfigurationUnavailableShell />;
    }

    throw error;
  }

  const supabase = await createSupabaseServerClient();
  const { data, error } = await supabase.auth.getClaims();

  if (error || !isVerifiedRecoverySession(data?.claims)) {
    redirect(getLoginRedirectPath(LOGIN_STATUS_RECOVERY_FAILED));
  }

  return (
    <SiteShell>
      <main
        id="main-content"
        className="mx-auto flex min-h-screen max-w-6xl items-center px-6 py-16"
      >
        <section className="grid w-full gap-8 lg:grid-cols-[minmax(0,1.1fr)_minmax(20rem,28rem)] lg:items-center">
          <div className="space-y-6">
            <p className="text-sm font-semibold uppercase tracking-[0.3em] text-emerald-300">
              Badminton Store
            </p>
            <h1 className="text-4xl font-semibold tracking-tight text-white sm:text-5xl">
              Choose a new password
            </h1>
            <p className="max-w-2xl text-lg leading-8 text-slate-200">
              Set a new password for this account, then sign in again. This
              recovery session does not open the CMS dashboard.
            </p>
          </div>

          <div className="rounded-3xl border border-white/10 bg-slate-900/80 p-8 shadow-2xl shadow-slate-950/30">
            <h2 className="text-xl font-semibold text-white">New password</h2>
            <p className="mt-2 text-sm leading-6 text-slate-300">
              Use at least 12 characters and confirm the password.
            </p>
            <UpdatePasswordForm />
          </div>
        </section>
      </main>
    </SiteShell>
  );
}
