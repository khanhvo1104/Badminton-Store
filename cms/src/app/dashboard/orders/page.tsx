import type { ReactNode } from "react";

import { ErrorState } from "@/components/ui/error-state";
import { OrderFilters } from "@/features/orders/components/order-filters";
import { OrderList } from "@/features/orders/components/order-list";
import { ORDERS_AUTH_DENIED_MESSAGE } from "@/features/orders/constants";
import { listOrders, type OrdersQueryClient } from "@/features/orders/queries";
import { parseOrdersExplorerQuery } from "@/features/orders/validation";
import {
  type AuthorizationSupabaseClient,
  authorizeCmsRequest,
} from "@/lib/auth/authorization";
import { createSupabaseServerClient } from "@/lib/supabase/server";

export const dynamic = "force-dynamic";

type OrdersPageProps = {
  searchParams?: Promise<Record<string, string | string[] | undefined>>;
};

export default async function OrdersPage({ searchParams }: OrdersPageProps) {
  const resolvedSearchParams = (await searchParams) ?? {};
  const query = parseOrdersExplorerQuery(resolvedSearchParams);

  const supabase = await createSupabaseServerClient();
  const authorization = await authorizeCmsRequest(
    supabase as unknown as AuthorizationSupabaseClient,
  );

  if (authorization.kind !== "authorized") {
    return (
      <OrdersExplorerShell>
        <ErrorState
          title="Orders unavailable"
          description={ORDERS_AUTH_DENIED_MESSAGE}
        />
      </OrdersExplorerShell>
    );
  }

  const listed = await listOrders({
    supabase: supabase as unknown as OrdersQueryClient,
    query,
  });

  return (
    <OrdersExplorerShell>
      <OrderFilters query={query} />
      {!listed.ok ? (
        <ErrorState title="Orders unavailable" description={listed.message} />
      ) : (
        <OrderList result={listed.result} />
      )}
    </OrdersExplorerShell>
  );
}

function OrdersExplorerShell({ children }: { children: ReactNode }) {
  return (
    <div className="mx-auto max-w-6xl space-y-8">
      <header className="space-y-3">
        <p className="text-sm font-semibold uppercase tracking-[0.3em] text-emerald-300">
          Orders
        </p>
        <h1 className="text-3xl font-semibold tracking-tight text-white sm:text-4xl">
          Orders
        </h1>
        <p className="max-w-3xl text-base leading-7 text-slate-300">
          Search and filter customer orders with server-side pagination. Open an
          order to review trusted totals, shipping snapshots, and transition
          status through the atomic staff workflow.
        </p>
      </header>
      {children}
    </div>
  );
}
