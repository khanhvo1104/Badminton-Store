import type { ReactNode } from "react";

import Link from "next/link";

import {
  INVENTORY_LIST_PATH,
  INVENTORY_SEARCH_MAX_LENGTH,
  INVENTORY_SORT_LABELS,
  INVENTORY_SORTS,
  INVENTORY_STOCK_LABELS,
  INVENTORY_STOCK_STATES,
} from "@/features/inventory/constants";
import type { InventoryExplorerQuery } from "@/features/inventory/types";

type InventoryFiltersProps = {
  query: InventoryExplorerQuery;
};

export function InventoryFilters({ query }: InventoryFiltersProps) {
  return (
    <form
      method="get"
      action={INVENTORY_LIST_PATH}
      className="space-y-4 rounded-3xl border border-white/10 bg-slate-900/60 p-5"
    >
      <div className="grid gap-4 md:grid-cols-2 xl:grid-cols-3">
        <Field id="inventory-search" label="Search">
          <input
            id="inventory-search"
            name="q"
            type="search"
            defaultValue={query.search}
            maxLength={INVENTORY_SEARCH_MAX_LENGTH}
            placeholder="Product, variant, or SKU"
            className={inputClassName}
          />
        </Field>
        <Field id="inventory-stock" label="Stock">
          <select
            id="inventory-stock"
            name="stock"
            defaultValue={query.stock}
            className={inputClassName}
          >
            {INVENTORY_STOCK_STATES.map((stock) => (
              <option key={stock} value={stock}>
                {INVENTORY_STOCK_LABELS[stock]}
              </option>
            ))}
          </select>
        </Field>
        <Field id="inventory-sort" label="Sort">
          <select
            id="inventory-sort"
            name="sort"
            defaultValue={query.sort}
            className={inputClassName}
          >
            {INVENTORY_SORTS.map((sort) => (
              <option key={sort} value={sort}>
                {INVENTORY_SORT_LABELS[sort]}
              </option>
            ))}
          </select>
        </Field>
      </div>
      <div className="flex flex-wrap items-center gap-3">
        <button
          type="submit"
          className="inline-flex rounded-full bg-emerald-300 px-5 py-3 text-sm font-semibold text-slate-950 transition hover:bg-emerald-200 focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-emerald-200"
        >
          Apply filters
        </button>
        <Link
          href={INVENTORY_LIST_PATH}
          className="inline-flex rounded-full border border-white/15 px-5 py-3 text-sm font-semibold text-white transition hover:border-white/30 hover:bg-white/5 focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-emerald-200"
        >
          Clear filters
        </Link>
      </div>
    </form>
  );
}

function Field({
  id,
  label,
  children,
}: {
  id: string;
  label: string;
  children: ReactNode;
}) {
  return (
    <div className="space-y-2">
      <label htmlFor={id} className="text-sm font-medium text-slate-100">
        {label}
      </label>
      {children}
    </div>
  );
}

const inputClassName =
  "w-full rounded-2xl border border-white/10 bg-slate-950/70 px-4 py-3 text-base text-white outline-none transition focus:border-emerald-300 focus:ring-2 focus:ring-emerald-300/30";
