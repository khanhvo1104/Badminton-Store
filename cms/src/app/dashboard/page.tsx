import type { ReactNode } from "react";

import { ErrorState } from "@/components/ui/error-state";
import { OperationalDashboard } from "@/features/operational-dashboard/components/operational-dashboard";
import { DASHBOARD_AUTH_DENIED_MESSAGE } from "@/features/operational-dashboard/constants";
import {
  getOperationalDashboard,
  type OperationalDashboardQueryClient,
} from "@/features/operational-dashboard/queries";
import { parseDashboardQuery } from "@/features/operational-dashboard/validation";
import {
  type AuthorizationSupabaseClient,
  authorizeCmsRequest,
} from "@/lib/auth/authorization";
import { createSupabaseServerClient } from "@/lib/supabase/server";

export const dynamic = "force-dynamic";

type DashboardOverviewPageProps = {
  searchParams?: Promise<Record<string, string | string[] | undefined>>;
};

export default async function DashboardOverviewPage({
  searchParams,
}: DashboardOverviewPageProps) {
  const resolvedSearchParams = (await searchParams) ?? {};
  const query = parseDashboardQuery(resolvedSearchParams);

  const supabase = await createSupabaseServerClient();
  const authorization = await authorizeCmsRequest(
    supabase as unknown as AuthorizationSupabaseClient,
  );

  if (authorization.kind !== "authorized") {
    return (
      <DashboardOverviewShell>
        <ErrorState
          title="Dashboard unavailable"
          description={DASHBOARD_AUTH_DENIED_MESSAGE}
        />
      </DashboardOverviewShell>
    );
  }

  const loaded = await getOperationalDashboard({
    supabase: supabase as unknown as OperationalDashboardQueryClient,
    query,
  });

  return (
    <DashboardOverviewShell>
      {!loaded.ok ? (
        <ErrorState
          title="Dashboard unavailable"
          description={loaded.message}
        />
      ) : (
        <OperationalDashboard snapshot={loaded.snapshot} query={query} />
      )}
    </DashboardOverviewShell>
  );
}

function DashboardOverviewShell({ children }: { children: ReactNode }) {
  return (
    <div className="mx-auto max-w-6xl space-y-8">
      <header className="space-y-3">
        <p className="text-sm font-semibold uppercase tracking-[0.3em] text-emerald-300">
          Dashboard
        </p>
        <h1 className="text-3xl font-semibold tracking-tight text-white sm:text-4xl">
          Operational overview
        </h1>
        <p className="max-w-3xl text-base leading-7 text-slate-300">
          Sales signals and low-stock alerts for staff and admins. Metrics load
          once from a trusted database RPC with currency-aware gross totals and
          no client-side aggregation of unbounded orders or inventory.
        </p>
      </header>
      {children}
    </div>
  );
}
