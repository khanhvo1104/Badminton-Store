import Link from "next/link";

import { EmptyState } from "@/components/ui/empty-state";
import { StatusBadge } from "@/components/ui/status-badge";
import { InventoryPagination } from "@/features/inventory/components/inventory-pagination";
import {
  INVENTORY_LIST_PATH,
  inventoryAdjustmentPath,
} from "@/features/inventory/constants";
import type {
  InventoryListItem,
  InventoryListResult,
} from "@/features/inventory/types";
import { inventoryExplorerHref } from "@/features/inventory/validation";

type InventoryListProps = {
  result: InventoryListResult;
};

export function InventoryList({ result }: InventoryListProps) {
  if (result.items.length === 0 && result.pagination.page > 1) {
    return (
      <EmptyState
        title="No variants on this page"
        description="This page is outside the current result set. Go back to the first page."
        action={
          <Link
            href={inventoryExplorerHref({
              ...result.query,
              pagination: { page: 1, pageSize: result.pagination.pageSize },
            })}
            className="inline-flex rounded-full bg-emerald-300 px-5 py-3 text-sm font-semibold text-slate-950 transition hover:bg-emerald-200 focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-emerald-200"
          >
            Back to first page
          </Link>
        }
      />
    );
  }

  if (result.items.length === 0) {
    return (
      <EmptyState
        title={
          result.hasActiveFilters
            ? "No inventory matches these filters"
            : "No variants yet"
        }
        description={
          result.hasActiveFilters
            ? "Clear the search or filters to see more inventory rows."
            : "Variants created in the catalog will appear here for stock review."
        }
        action={
          result.hasActiveFilters ? (
            <Link
              href={INVENTORY_LIST_PATH}
              className="inline-flex rounded-full bg-emerald-300 px-5 py-3 text-sm font-semibold text-slate-950 transition hover:bg-emerald-200 focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-emerald-200"
            >
              Clear filters
            </Link>
          ) : null
        }
      />
    );
  }

  return (
    <div className="space-y-6">
      <div className="grid gap-4 lg:hidden">
        {result.items.map((item) => (
          <InventoryCard key={item.variantId} item={item} />
        ))}
      </div>

      <div className="hidden overflow-x-auto rounded-3xl border border-white/10 bg-slate-900/60 lg:block">
        <table className="min-w-full text-left text-sm text-slate-200">
          <thead className="border-b border-white/10 text-xs uppercase tracking-[0.2em] text-slate-400">
            <tr>
              <th scope="col" className="px-4 py-4 font-semibold">
                Product
              </th>
              <th scope="col" className="px-4 py-4 font-semibold">
                Variant / SKU
              </th>
              <th scope="col" className="px-4 py-4 font-semibold">
                On hand
              </th>
              <th scope="col" className="px-4 py-4 font-semibold">
                Reserved
              </th>
              <th scope="col" className="px-4 py-4 font-semibold">
                Available
              </th>
              <th scope="col" className="px-4 py-4 font-semibold">
                Reorder level
              </th>
              <th scope="col" className="px-4 py-4 font-semibold">
                Allow backorder
              </th>
              <th scope="col" className="px-4 py-4 font-semibold">
                Status
              </th>
              <th scope="col" className="px-4 py-4 font-semibold">
                Updated
              </th>
              <th scope="col" className="px-4 py-4 font-semibold">
                Actions
              </th>
            </tr>
          </thead>
          <tbody>
            {result.items.map((item) => (
              <tr
                key={item.variantId}
                className="border-b border-white/5 last:border-b-0"
              >
                <td className="px-4 py-4 align-top">
                  <p className="font-semibold text-white">{item.productName}</p>
                </td>
                <td className="px-4 py-4 align-top">
                  <p className="font-semibold text-white">
                    {item.variantName ?? "Unnamed variant"}
                  </p>
                  <p className="text-xs text-slate-400">{item.sku}</p>
                </td>
                <td className="px-4 py-4 align-top text-slate-300">
                  {formatCount(item.quantityOnHand)}
                </td>
                <td className="px-4 py-4 align-top text-slate-300">
                  {formatCount(item.quantityReserved)}
                </td>
                <td className="px-4 py-4 align-top text-slate-300">
                  {formatCount(item.quantityAvailable)}
                </td>
                <td className="px-4 py-4 align-top text-slate-300">
                  {formatCount(item.reorderLevel)}
                </td>
                <td className="px-4 py-4 align-top text-slate-300">
                  {item.allowBackorderLabel}
                </td>
                <td className="px-4 py-4 align-top">
                  <StatusBadge tone={stockTone(item.stockState)}>
                    {item.stockLabel}
                  </StatusBadge>
                </td>
                <td className="px-4 py-4 align-top text-slate-300">
                  {item.updatedAtLabel}
                </td>
                <td className="px-4 py-4 align-top">
                  <AdjustLink item={item} />
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      <InventoryPagination result={result} />
    </div>
  );
}

function InventoryCard({ item }: { item: InventoryListItem }) {
  return (
    <article className="space-y-4 rounded-3xl border border-white/10 bg-slate-900/60 p-5">
      <div>
        <h2 className="text-lg font-semibold text-white">{item.productName}</h2>
        <p className="text-sm text-slate-300">
          {item.variantName ?? "Unnamed variant"}
        </p>
        <p className="text-xs text-slate-400">{item.sku}</p>
      </div>
      <dl className="grid gap-3 text-sm text-slate-300">
        <Info label="On hand" value={formatCount(item.quantityOnHand)} />
        <Info label="Reserved" value={formatCount(item.quantityReserved)} />
        <Info label="Available" value={formatCount(item.quantityAvailable)} />
        <Info label="Reorder level" value={formatCount(item.reorderLevel)} />
        <Info label="Allow backorder" value={item.allowBackorderLabel} />
        <div>
          <dt className="text-xs uppercase tracking-[0.2em] text-slate-500">
            Status
          </dt>
          <dd className="mt-1">
            <StatusBadge tone={stockTone(item.stockState)}>
              {item.stockLabel}
            </StatusBadge>
          </dd>
        </div>
        <Info label="Updated" value={item.updatedAtLabel} />
      </dl>
      <AdjustLink item={item} />
    </article>
  );
}

function AdjustLink({ item }: { item: InventoryListItem }) {
  return (
    <Link
      href={inventoryAdjustmentPath(item.variantId)}
      aria-label={`Adjust inventory for ${item.sku}`}
      className="inline-flex rounded-full bg-emerald-300 px-3 py-1 text-sm font-semibold text-slate-950 transition hover:bg-emerald-200 focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-emerald-200"
    >
      Adjust
    </Link>
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

function stockTone(
  status: InventoryListItem["stockState"],
): "success" | "neutral" | "danger" {
  if (status === "in_stock") {
    return "success";
  }
  if (status === "out_of_stock" || status === "missing") {
    return "danger";
  }
  return "neutral";
}
