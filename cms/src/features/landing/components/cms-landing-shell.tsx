import Link from "next/link";

import { SiteShell } from "@/components/layout/site-shell";
import { StatusBadge } from "@/components/ui/status-badge";

const readinessItems = [
  "Supabase public environment validation is wired.",
  "Authentication, catalog data, and admin workflows are intentionally not connected yet.",
  "This foundation is ready for the dedicated auth task to build on top of it.",
];

export function CmsLandingShell() {
  return (
    <SiteShell>
      <header className="border-b border-white/10">
        <div className="mx-auto flex max-w-6xl items-center justify-between gap-4 px-6 py-5">
          <div>
            <p className="text-sm font-semibold uppercase tracking-[0.3em] text-emerald-300">
              Badminton Store
            </p>
            <p className="mt-2 text-lg font-medium text-white">
              CMS foundation
            </p>
          </div>
          <StatusBadge>Scaffold only</StatusBadge>
        </div>
      </header>

      <main id="main-content" className="mx-auto max-w-6xl px-6 py-16 sm:py-24">
        <section className="grid gap-8 lg:grid-cols-[minmax(0,1.3fr)_minmax(18rem,1fr)] lg:items-start">
          <div className="rounded-3xl border border-white/10 bg-white/5 p-8 shadow-2xl shadow-slate-950/20 sm:p-10">
            <p className="text-sm font-semibold uppercase tracking-[0.3em] text-emerald-300">
              Administration product
            </p>
            <h1 className="mt-4 text-4xl font-semibold tracking-tight text-white sm:text-5xl">
              Badminton Store CMS
            </h1>
            <p className="mt-6 max-w-2xl text-lg leading-8 text-slate-200">
              This independently runnable Next.js application is the foundation
              for staff-facing administration. It currently presents a static
              shell only, with honest setup feedback and no live Supabase
              client, authentication session, or catalog integration.
            </p>
            <div className="mt-8 flex flex-wrap gap-4">
              <Link
                href="/"
                className="rounded-full bg-emerald-300 px-5 py-3 text-sm font-semibold text-slate-950 transition hover:bg-emerald-200 focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-emerald-200"
              >
                View foundation shell
              </Link>
              <span className="rounded-full border border-white/15 px-5 py-3 text-sm font-semibold text-white">
                Auth arrives in TASK-025
              </span>
            </div>
          </div>

          <aside
            aria-labelledby="cms-readiness-heading"
            className="rounded-3xl border border-white/10 bg-slate-900/80 p-8"
          >
            <h2
              id="cms-readiness-heading"
              className="text-xl font-semibold tracking-tight text-white"
            >
              What this scaffold includes
            </h2>
            <ul className="mt-5 space-y-4 text-sm leading-7 text-slate-200">
              {readinessItems.map((item) => (
                <li key={item} className="flex gap-3">
                  <span
                    aria-hidden="true"
                    className="mt-2 h-2.5 w-2.5 rounded-full bg-emerald-300"
                  />
                  <span>{item}</span>
                </li>
              ))}
            </ul>
          </aside>
        </section>
      </main>

      <footer className="border-t border-white/10">
        <div className="mx-auto max-w-6xl px-6 py-6 text-sm text-slate-300">
          Public Supabase settings are validated at startup, but no network
          request is made from this scaffold.
        </div>
      </footer>
    </SiteShell>
  );
}
