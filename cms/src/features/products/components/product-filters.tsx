import type { ReactNode } from "react";

import Link from "next/link";

import {
  PRODUCT_SEARCH_MAX_LENGTH,
  PRODUCT_SORT_LABELS,
  PRODUCT_SORTS,
  PRODUCT_STATUS_LABELS,
  PRODUCT_STATUSES,
  PRODUCT_STOCK_LABELS,
  PRODUCT_STOCK_STATES,
  PRODUCTS_LIST_PATH,
} from "@/features/products/constants";
import type {
  ProductExplorerQuery,
  ProductFilterOption,
} from "@/features/products/types";

type ProductFiltersProps = {
  query: ProductExplorerQuery;
  categories: ProductFilterOption[];
  brands: ProductFilterOption[];
};

export function ProductFilters({
  query,
  categories,
  brands,
}: ProductFiltersProps) {
  return (
    <form
      method="get"
      action={PRODUCTS_LIST_PATH}
      className="space-y-4 rounded-3xl border border-white/10 bg-slate-900/60 p-5"
    >
      <div className="grid gap-4 md:grid-cols-2 xl:grid-cols-3">
        <Field id="product-search" label="Search">
          <input
            id="product-search"
            name="q"
            type="search"
            defaultValue={query.search}
            maxLength={PRODUCT_SEARCH_MAX_LENGTH}
            placeholder="Name or slug"
            className={inputClassName}
          />
        </Field>
        <Field id="product-category" label="Category">
          <select
            id="product-category"
            name="category"
            defaultValue={query.categoryId ?? ""}
            className={inputClassName}
          >
            <option value="">All categories</option>
            {categories.map((option) => (
              <option key={option.id} value={option.id}>
                {option.isActive ? option.name : `${option.name} (inactive)`}
              </option>
            ))}
          </select>
        </Field>
        <Field id="product-brand" label="Brand">
          <select
            id="product-brand"
            name="brand"
            defaultValue={query.brandId ?? ""}
            className={inputClassName}
          >
            <option value="">All brands</option>
            {brands.map((option) => (
              <option key={option.id} value={option.id}>
                {option.isActive ? option.name : `${option.name} (inactive)`}
              </option>
            ))}
          </select>
        </Field>
        <Field id="product-status" label="Status">
          <select
            id="product-status"
            name="status"
            defaultValue={query.status ?? ""}
            className={inputClassName}
          >
            <option value="">All statuses</option>
            {PRODUCT_STATUSES.map((status) => (
              <option key={status} value={status}>
                {PRODUCT_STATUS_LABELS[status]}
              </option>
            ))}
          </select>
        </Field>
        <Field id="product-stock" label="Stock">
          <select
            id="product-stock"
            name="stock"
            defaultValue={query.stock}
            className={inputClassName}
          >
            {PRODUCT_STOCK_STATES.map((stock) => (
              <option key={stock} value={stock}>
                {PRODUCT_STOCK_LABELS[stock]}
              </option>
            ))}
          </select>
        </Field>
        <Field id="product-sort" label="Sort">
          <select
            id="product-sort"
            name="sort"
            defaultValue={query.sort}
            className={inputClassName}
          >
            {PRODUCT_SORTS.map((sort) => (
              <option key={sort} value={sort}>
                {PRODUCT_SORT_LABELS[sort]}
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
          href={PRODUCTS_LIST_PATH}
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
