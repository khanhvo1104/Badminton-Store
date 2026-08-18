import type { ReactNode } from "react";

import { ErrorState } from "@/components/ui/error-state";
import { InventoryFilters } from "@/features/inventory/components/inventory-filters";
import { InventoryList } from "@/features/inventory/components/inventory-list";
import { INVENTORY_AUTH_DENIED_MESSAGE } from "@/features/inventory/constants";
import {
  listInventory,
  type InventoryQueryClient,
} from "@/features/inventory/queries";
import { parseInventoryExplorerQuery } from "@/features/inventory/validation";
import {
  type AuthorizationSupabaseClient,
  authorizeCmsRequest,
} from "@/lib/auth/authorization";
import { createSupabaseServerClient } from "@/lib/supabase/server";

export const dynamic = "force-dynamic";

type InventoryPageProps = {
  searchParams?: Promise<Record<string, string | string[] | undefined>>;
};

export default async function InventoryPage({
  searchParams,
}: InventoryPageProps) {
  const resolvedSearchParams = (await searchParams) ?? {};
  const query = parseInventoryExplorerQuery(resolvedSearchParams);

  const supabase = await createSupabaseServerClient();
  const authorization = await authorizeCmsRequest(
    supabase as unknown as AuthorizationSupabaseClient,
  );

  if (authorization.kind !== "authorized") {
    return (
      <InventoryExplorerShell>
        <ErrorState
          title="Inventory unavailable"
          description={INVENTORY_AUTH_DENIED_MESSAGE}
        />
      </InventoryExplorerShell>
    );
  }

  const listed = await listInventory({
    supabase: supabase as unknown as InventoryQueryClient,
    query,
  });

  return (
    <InventoryExplorerShell>
      <InventoryFilters query={query} />
      {!listed.ok ? (
        <ErrorState
          title="Inventory unavailable"
          description={listed.message}
        />
      ) : (
        <InventoryList result={listed.result} />
      )}
    </InventoryExplorerShell>
  );
}

function InventoryExplorerShell({ children }: { children: ReactNode }) {
  return (
    <div className="mx-auto max-w-6xl space-y-8">
      <header className="space-y-3">
        <p className="text-sm font-semibold uppercase tracking-[0.3em] text-emerald-300">
          Inventory
        </p>
        <h1 className="text-3xl font-semibold tracking-tight text-white sm:text-4xl">
          Inventory
        </h1>
        <p className="max-w-3xl text-base leading-7 text-slate-300">
          Review per-variant stock with server-side search, filters, and
          sorting. Adjust on-hand, reorder level, and allow-backorder through
          the trusted adjustment flow. Reserved quantity stays read-only.
        </p>
      </header>
      {children}
    </div>
  );
}
