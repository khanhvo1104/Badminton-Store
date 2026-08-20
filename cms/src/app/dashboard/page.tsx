import Link from "next/link";

import { DASHBOARD_NAV_ITEMS } from "@/lib/navigation/dashboard-routes";

export default function DashboardOverviewPage() {
  const quickAccess = DASHBOARD_NAV_ITEMS.filter(
    (item) => item.id !== "overview",
  );

  return (
    <div className="mx-auto max-w-5xl space-y-8">
      <header className="space-y-3">
        <p className="text-sm font-semibold uppercase tracking-[0.3em] text-emerald-300">
          Dashboard
        </p>
        <h1 className="text-3xl font-semibold tracking-tight text-white sm:text-4xl">
          Catalog management workspace
        </h1>
        <p className="max-w-3xl text-base leading-7 text-slate-300">
          This shell prepares staff and admins for catalog, inventory, and order
          workflows. No live sales totals or business metrics are loaded here.
        </p>
      </header>

      <section aria-labelledby="cms-scope-heading" className="space-y-4">
        <h2
          id="cms-scope-heading"
          className="text-xl font-semibold tracking-tight text-white"
        >
          Current CMS scope
        </h2>
        <p className="max-w-3xl text-sm leading-7 text-slate-300">
          Use the navigation to reach protected catalog, inventory, and order
          areas. Authorization continues to run on the server for every
          protected request.
        </p>
      </section>

      <section aria-labelledby="quick-access-heading" className="space-y-4">
        <h2
          id="quick-access-heading"
          className="text-xl font-semibold tracking-tight text-white"
        >
          Quick access
        </h2>
        <ul className="grid gap-4 sm:grid-cols-2">
          {quickAccess.map((item) => (
            <li key={item.id}>
              <Link
                href={item.href}
                className="block h-full rounded-3xl border border-white/10 bg-slate-900/70 p-6 transition hover:border-emerald-300/40 hover:bg-slate-900 focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-emerald-200"
              >
                <h3 className="text-lg font-semibold text-white">
                  {item.label}
                </h3>
                <p className="mt-2 text-sm leading-7 text-slate-300">
                  {item.description}
                </p>
              </Link>
            </li>
          ))}
        </ul>
      </section>
    </div>
  );
}
