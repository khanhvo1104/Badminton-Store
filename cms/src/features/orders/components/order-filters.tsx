import Link from "next/link";

import type { ReactNode } from "react";

import {
  ORDERS_DEFAULT_PAYMENT_STATUS,
  ORDERS_DEFAULT_SORT,
  ORDERS_DEFAULT_STATUS,
  ORDERS_LIST_PATH,
  ORDER_SORT_LABELS,
  ORDER_SORTS,
  ORDER_STATUS_FILTERS,
  ORDER_STATUS_LABELS,
  PAYMENT_STATUS_FILTERS,
  PAYMENT_STATUS_LABELS,
} from "@/features/orders/constants";
import type { OrdersExplorerQuery } from "@/features/orders/types";
import { ordersExplorerHref } from "@/features/orders/validation";

type OrderFiltersProps = {
  query: OrdersExplorerQuery;
};

export function OrderFilters({ query }: OrderFiltersProps) {
  return (
    <form
      method="get"
      action={ORDERS_LIST_PATH}
      className="space-y-4 rounded-3xl border border-white/10 bg-slate-900/60 p-5"
      role="search"
      aria-label="Filter orders"
    >
      <div className="grid gap-4 md:grid-cols-2 xl:grid-cols-3">
        <Field id="q" label="Search">
          <input
            id="q"
            name="q"
            type="search"
            defaultValue={query.search}
            maxLength={80}
            placeholder="Order number, recipient, phone"
            className={inputClassName}
          />
        </Field>
        <Field id="status" label="Order status">
          <select
            id="status"
            name="status"
            defaultValue={query.status}
            className={inputClassName}
          >
            {ORDER_STATUS_FILTERS.map((status) => (
              <option key={status} value={status}>
                {ORDER_STATUS_LABELS[status]}
              </option>
            ))}
          </select>
        </Field>
        <Field id="paymentStatus" label="Payment status">
          <select
            id="paymentStatus"
            name="paymentStatus"
            defaultValue={query.paymentStatus}
            className={inputClassName}
          >
            {PAYMENT_STATUS_FILTERS.map((status) => (
              <option key={status} value={status}>
                {PAYMENT_STATUS_LABELS[status]}
              </option>
            ))}
          </select>
        </Field>
        <Field id="placedFrom" label="Placed from (UTC)">
          <input
            id="placedFrom"
            name="placedFrom"
            type="datetime-local"
            defaultValue={toDatetimeLocalValue(query.placedFrom)}
            className={inputClassName}
          />
        </Field>
        <Field id="placedTo" label="Placed to (UTC)">
          <input
            id="placedTo"
            name="placedTo"
            type="datetime-local"
            defaultValue={toDatetimeLocalValue(query.placedTo)}
            className={inputClassName}
          />
        </Field>
        <Field id="sort" label="Sort">
          <select
            id="sort"
            name="sort"
            defaultValue={query.sort}
            className={inputClassName}
          >
            {ORDER_SORTS.map((sort) => (
              <option key={sort} value={sort}>
                {ORDER_SORT_LABELS[sort]}
              </option>
            ))}
          </select>
        </Field>
      </div>
      <input
        type="hidden"
        name="pageSize"
        value={String(query.pagination.pageSize)}
      />
      <div className="flex flex-wrap gap-3">
        <button
          type="submit"
          className="rounded-full bg-emerald-300 px-5 py-3 text-sm font-semibold text-slate-950 transition hover:bg-emerald-200 focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-emerald-200"
        >
          Apply filters
        </button>
        {(query.search ||
          query.status !== ORDERS_DEFAULT_STATUS ||
          query.paymentStatus !== ORDERS_DEFAULT_PAYMENT_STATUS ||
          query.placedFrom ||
          query.placedTo ||
          query.sort !== ORDERS_DEFAULT_SORT) && (
          <Link
            href={ordersExplorerHref({
              search: "",
              status: ORDERS_DEFAULT_STATUS,
              paymentStatus: ORDERS_DEFAULT_PAYMENT_STATUS,
              placedFrom: null,
              placedTo: null,
              sort: ORDERS_DEFAULT_SORT,
              pagination: { page: 1, pageSize: query.pagination.pageSize },
            })}
            className="inline-flex rounded-full border border-white/15 px-5 py-3 text-sm font-semibold text-white transition hover:border-white/30 hover:bg-white/5 focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-emerald-200"
          >
            Clear filters
          </Link>
        )}
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
      <label htmlFor={id} className="text-sm font-semibold text-white">
        {label}
      </label>
      {children}
    </div>
  );
}

function toDatetimeLocalValue(iso: string | null): string {
  if (!iso) {
    return "";
  }
  const date = new Date(iso);
  if (!Number.isFinite(date.getTime())) {
    return "";
  }
  const pad = (value: number) => String(value).padStart(2, "0");
  return `${date.getUTCFullYear()}-${pad(date.getUTCMonth() + 1)}-${pad(date.getUTCDate())}T${pad(date.getUTCHours())}:${pad(date.getUTCMinutes())}`;
}

const inputClassName =
  "w-full rounded-2xl border border-white/10 bg-slate-950 px-4 py-3 text-sm text-white outline-none transition focus:border-emerald-300/50";
