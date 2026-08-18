import Link from "next/link";
import { notFound } from "next/navigation";

import { ErrorState } from "@/components/ui/error-state";
import { StatusBadge } from "@/components/ui/status-badge";
import { InventoryAdjustmentForm } from "@/features/inventory/components/inventory-adjustment-form";
import { INVENTORY_LIST_PATH } from "@/features/inventory/constants";
import {
  getInventoryVariant,
  type InventoryQueryClient,
} from "@/features/inventory/queries";
import { inventorySuccessMessage } from "@/features/inventory/success-message";
import type { InventoryDetail } from "@/features/inventory/types";
import { isValidUuid } from "@/features/products/validation";
import { createSupabaseServerClient } from "@/lib/supabase/server";

export const dynamic = "force-dynamic";

type InventoryAdjustmentPageProps = {
  params: Promise<{ variantId: string }>;
  searchParams?: Promise<Record<string, string | string[] | undefined>>;
};

export default async function InventoryAdjustmentPage({
  params,
  searchParams,
}: InventoryAdjustmentPageProps) {
  const { variantId } = await params;
  const resolvedSearchParams = (await searchParams) ?? {};

  if (!isValidUuid(variantId)) {
    notFound();
  }

  const supabase = await createSupabaseServerClient();
  const result = await getInventoryVariant({
    supabase: supabase as unknown as InventoryQueryClient,
    variantId,
  });

  if (!result.ok && result.notFound) {
    notFound();
  }

  if (!result.ok) {
    return (
      <div className="mx-auto max-w-3xl">
        <ErrorState
          title="Unable to load inventory"
          description={result.message}
        />
      </div>
    );
  }

  const successMessage = inventorySuccessMessage(resolvedSearchParams.success);

  return (
    <div className="mx-auto max-w-3xl space-y-8">
      <header className="space-y-3">
        <p className="text-sm font-semibold uppercase tracking-[0.3em] text-emerald-300">
          Inventory
        </p>
        <h1 className="text-3xl font-semibold tracking-tight text-white sm:text-4xl">
          Adjust inventory
        </h1>
        <p className="max-w-2xl text-base leading-7 text-slate-300">
          Update on-hand stock, reorder level, or allow-backorder for SKU{" "}
          {result.detail.sku}. Reserved quantity cannot be edited.
        </p>
        <Link
          href={INVENTORY_LIST_PATH}
          className="inline-flex font-semibold text-emerald-200 underline-offset-4 hover:underline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-emerald-200"
        >
          Back to inventory
        </Link>
      </header>

      {successMessage ? (
        <p
          role="status"
          aria-live="polite"
          className="rounded-3xl border border-emerald-300/20 bg-emerald-300/10 px-5 py-4 text-sm text-emerald-100"
        >
          {successMessage}
        </p>
      ) : null}

      <InventorySummary detail={result.detail} />

      <InventoryAdjustmentForm
        variantId={variantId}
        initialAllowBackorder={result.detail.allowBackorder}
      />

      <HistoryList detail={result.detail} />
    </div>
  );
}

function InventorySummary({ detail }: { detail: InventoryDetail }) {
  return (
    <section
      aria-labelledby="current-stock-heading"
      className="space-y-4 rounded-3xl border border-white/10 bg-slate-900/60 p-5"
    >
      <h2
        id="current-stock-heading"
        className="text-lg font-semibold text-white"
      >
        Current stock
      </h2>
      <dl className="grid gap-4 sm:grid-cols-2 text-sm text-slate-300">
        <Info label="Product" value={detail.productName} />
        <Info
          label="Variant / SKU"
          value={`${detail.variantName ?? "Unnamed variant"} · ${detail.sku}`}
        />
        <Info label="On hand" value={formatCount(detail.quantityOnHand)} />
        <Info label="Reserved" value={formatCount(detail.quantityReserved)} />
        <Info label="Available" value={formatCount(detail.quantityAvailable)} />
        <Info label="Reorder level" value={formatCount(detail.reorderLevel)} />
        <Info label="Allow backorder" value={detail.allowBackorderLabel} />
        <div>
          <dt className="text-xs uppercase tracking-[0.2em] text-slate-500">
            Status
          </dt>
          <dd className="mt-1">
            <StatusBadge
              tone={
                detail.stockState === "in_stock"
                  ? "success"
                  : detail.stockState === "out_of_stock" ||
                      detail.stockState === "missing"
                    ? "danger"
                    : "neutral"
              }
            >
              {detail.stockLabel}
            </StatusBadge>
          </dd>
        </div>
        <Info label="Updated" value={detail.updatedAtLabel} />
      </dl>
    </section>
  );
}

function HistoryList({ detail }: { detail: InventoryDetail }) {
  return (
    <section aria-labelledby="history-heading" className="space-y-4">
      <h2 id="history-heading" className="text-lg font-semibold text-white">
        Recent adjustments
      </h2>
      {detail.history.length === 0 ? (
        <p className="text-sm text-slate-400">No adjustments recorded yet.</p>
      ) : (
        <ol className="space-y-3">
          {detail.history.map((item) => (
            <li
              key={item.id}
              className="rounded-3xl border border-white/10 bg-slate-900/60 p-4 text-sm text-slate-300"
            >
              <p className="font-semibold text-white">
                {item.operationLabel} · {item.reasonLabel}
              </p>
              <p className="mt-1 text-xs text-slate-400">
                {item.createdAtLabel} · {item.actorName}
              </p>
              <p className="mt-2">
                On hand {item.quantityOnHandBefore} → {item.quantityOnHandAfter}
                {" · "}Reserved {item.quantityReserved}
                {" · "}Reorder {item.reorderLevelBefore} →{" "}
                {item.reorderLevelAfter}
              </p>
              {item.note ? <p className="mt-1">{item.note}</p> : null}
            </li>
          ))}
        </ol>
      )}
    </section>
  );
}

function Info({ label, value }: { label: string; value: string }) {
  return (
    <div>
      <dt className="text-xs uppercase tracking-[0.2em] text-slate-500">
        {label}
      </dt>
      <dd className="mt-1">{value}</dd>
    </div>
  );
}

function formatCount(value: number | null): string {
  return value === null ? "—" : String(value);
}
