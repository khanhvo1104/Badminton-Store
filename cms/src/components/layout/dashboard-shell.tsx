import type { ReactNode } from "react";
import { Suspense } from "react";

import { DashboardBreadcrumbsClient } from "@/components/layout/dashboard-breadcrumbs-client";
import { BreadcrumbList } from "@/components/layout/dashboard-breadcrumbs";
import { DashboardNavigation } from "@/components/layout/dashboard-navigation";
import { LogoutButton } from "@/components/layout/logout-button";
import {
  getSafeDisplayName,
  getTrustedRoleLabel,
  type SafeShellProfile,
} from "@/lib/navigation/dashboard-routes";

type DashboardShellProps = {
  profile: SafeShellProfile;
  children: ReactNode;
};

export function DashboardShell({ profile, children }: DashboardShellProps) {
  const displayName = getSafeDisplayName(profile);
  const roleLabel = getTrustedRoleLabel(profile.role);

  return (
    <div className="min-h-screen lg:grid lg:grid-cols-[16rem_minmax(0,1fr)]">
      <a
        href="#main-content"
        className="sr-only focus:not-sr-only focus:absolute focus:left-4 focus:top-4 focus:z-50 focus:rounded-full focus:bg-white focus:px-4 focus:py-2 focus:text-sm focus:font-semibold focus:text-slate-950"
      >
        Skip to content
      </a>

      <aside className="border-b border-white/10 bg-slate-950/70 lg:sticky lg:top-0 lg:flex lg:h-screen lg:flex-col lg:border-b-0 lg:border-r lg:border-white/10">
        <div className="flex items-start justify-between gap-4 px-5 py-5 lg:block lg:px-6 lg:py-8">
          <div>
            <p className="text-sm font-semibold uppercase tracking-[0.3em] text-emerald-300">
              Badminton Store
            </p>
            <p className="mt-2 text-lg font-medium text-white">CMS</p>
          </div>
          <div className="lg:mt-8">
            <Suspense fallback={<NavigationFallback />}>
              <DashboardNavigation />
            </Suspense>
          </div>
        </div>

        <div className="mt-auto hidden border-t border-white/10 px-6 py-6 lg:block">
          <AccountContext displayName={displayName} roleLabel={roleLabel} />
          <div className="mt-4">
            <LogoutButton />
          </div>
        </div>
      </aside>

      <div className="min-w-0">
        <header className="border-b border-white/10 bg-slate-950/40">
          <div className="flex flex-col gap-4 px-5 py-4 sm:px-8 lg:flex-row lg:items-center lg:justify-between">
            <Suspense
              fallback={
                <BreadcrumbList
                  items={[
                    { href: "/dashboard", label: "Overview", current: true },
                  ]}
                />
              }
            >
              <DashboardBreadcrumbsClient />
            </Suspense>

            <div className="flex items-center justify-between gap-4 lg:hidden">
              <AccountContext displayName={displayName} roleLabel={roleLabel} />
              <LogoutButton />
            </div>
          </div>
        </header>

        <main id="main-content" className="px-5 py-8 sm:px-8 sm:py-10">
          {children}
        </main>
      </div>
    </div>
  );
}

function AccountContext({
  displayName,
  roleLabel,
}: {
  displayName: string;
  roleLabel: string;
}) {
  return (
    <div className="min-w-0">
      <p className="truncate text-sm font-medium text-white">{displayName}</p>
      <p className="text-xs uppercase tracking-[0.2em] text-slate-400">
        {roleLabel}
      </p>
    </div>
  );
}

function NavigationFallback() {
  return (
    <nav aria-label="Primary navigation">
      <ul className="space-y-1">
        <li className="rounded-2xl bg-white/5 px-4 py-3 text-sm text-slate-400">
          Overview
        </li>
      </ul>
    </nav>
  );
}
