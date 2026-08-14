import { SiteShell } from "@/components/layout/site-shell";
import { ForgotPasswordForm } from "@/features/auth/components/forgot-password-form";
import { ConfigurationUnavailableShell } from "@/features/landing/components/configuration-unavailable-shell";
import { getCmsSiteUrl } from "@/lib/env/cms-site-url";
import { getPublicEnvironment } from "@/lib/env/public-env";
import { isPublicEnvironmentError } from "@/lib/errors/public-environment-error";

export const dynamic = "force-dynamic";

export default function ForgotPasswordPage() {
  try {
    getPublicEnvironment();
    getCmsSiteUrl();
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
        className="mx-auto flex min-h-screen max-w-6xl items-center px-6 py-16"
      >
        <section className="grid w-full gap-8 lg:grid-cols-[minmax(0,1.1fr)_minmax(20rem,28rem)] lg:items-center">
          <div className="space-y-6">
            <p className="text-sm font-semibold uppercase tracking-[0.3em] text-emerald-300">
              Badminton Store
            </p>
            <h1 className="text-4xl font-semibold tracking-tight text-white sm:text-5xl">
              Forgot password
            </h1>
            <p className="max-w-2xl text-lg leading-8 text-slate-200">
              Request a recovery email for an existing staff account. We will
              not say whether that email is registered.
            </p>
          </div>

          <div className="rounded-3xl border border-white/10 bg-slate-900/80 p-8 shadow-2xl shadow-slate-950/30">
            <h2 className="text-xl font-semibold text-white">Email recovery</h2>
            <p className="mt-2 text-sm leading-6 text-slate-300">
              Enter the email address for your CMS account.
            </p>
            <ForgotPasswordForm />
          </div>
        </section>
      </main>
    </SiteShell>
  );
}
