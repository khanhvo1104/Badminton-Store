import Link from "next/link";

import { EmptyState } from "@/components/ui/empty-state";
import { StatusBadge } from "@/components/ui/status-badge";
import { OrderPagination } from "@/features/orders/components/order-pagination";
import { ORDERS_LIST_PATH, orderDetailPath } from "@/features/orders/constants";
import type { OrderListItem, OrdersListResult } from "@/features/orders/types";
import { ordersExplorerHref } from "@/features/orders/validation";

type OrderListProps = {
  result: OrdersListResult;
};

export function OrderList({ result }: OrderListProps) {
  if (result.items.length === 0 && result.pagination.page > 1) {
    return (
      <EmptyState
        title="No orders on this page"
        description="This page is outside the current result set. Go back to the first page."
        action={
          <Link
            href={ordersExplorerHref({
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
            ? "No orders match these filters"
            : "No orders yet"
        }
        description={
          result.hasActiveFilters
            ? "Clear the search or filters to see more orders."
            : "Placed customer orders will appear here for staff review."
        }
        action={
          result.hasActiveFilters ? (
            <Link
              href={ORDERS_LIST_PATH}
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
          <OrderCard key={item.orderId} item={item} />
        ))}
      </div>

      <div className="hidden overflow-x-auto rounded-3xl border border-white/10 bg-slate-900/60 lg:block">
        <table className="min-w-full text-left text-sm text-slate-200">
          <thead className="border-b border-white/10 text-xs uppercase tracking-[0.2em] text-slate-400">
            <tr>
              <th scope="col" className="px-4 py-4 font-semibold">
                Order
              </th>
              <th scope="col" className="px-4 py-4 font-semibold">
                Recipient
              </th>
              <th scope="col" className="px-4 py-4 font-semibold">
                Status
              </th>
              <th scope="col" className="px-4 py-4 font-semibold">
                Payment
              </th>
              <th scope="col" className="px-4 py-4 font-semibold">
                Total
              </th>
              <th scope="col" className="px-4 py-4 font-semibold">
                Placed
              </th>
              <th scope="col" className="px-4 py-4 font-semibold">
                Items
              </th>
            </tr>
          </thead>
          <tbody>
            {result.items.map((item) => (
              <tr
                key={item.orderId}
                className="border-b border-white/5 last:border-b-0"
              >
                <td className="px-4 py-4">
                  <Link
                    href={orderDetailPath(item.orderId)}
                    className="font-semibold text-emerald-200 underline-offset-4 hover:underline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-emerald-200"
                  >
                    {item.orderNumber}
                  </Link>
                </td>
                <td className="px-4 py-4">
                  <p className="text-white">{item.recipientName}</p>
                  <p className="text-xs text-slate-400">
                    {item.recipientPhone}
                  </p>
                </td>
                <td className="px-4 py-4">
                  <StatusBadge tone={statusTone(item.status)}>
                    {item.statusLabel}
                  </StatusBadge>
                </td>
                <td className="px-4 py-4">{item.paymentStatusLabel}</td>
                <td className="px-4 py-4">{item.grandTotalLabel}</td>
                <td className="px-4 py-4">{item.placedAtLabel}</td>
                <td className="px-4 py-4">{item.itemCount}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      <OrderPagination result={result} />
    </div>
  );
}

function OrderCard({ item }: { item: OrderListItem }) {
  return (
    <article className="space-y-3 rounded-3xl border border-white/10 bg-slate-900/60 p-5">
      <div className="flex items-start justify-between gap-3">
        <div>
          <Link
            href={orderDetailPath(item.orderId)}
            className="text-lg font-semibold text-emerald-200 underline-offset-4 hover:underline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-emerald-200"
          >
            {item.orderNumber}
          </Link>
          <p className="mt-1 text-sm text-slate-300">{item.recipientName}</p>
          <p className="text-xs text-slate-400">{item.recipientPhone}</p>
        </div>
        <StatusBadge tone={statusTone(item.status)}>
          {item.statusLabel}
        </StatusBadge>
      </div>
      <dl className="grid grid-cols-2 gap-3 text-sm text-slate-300">
        <div>
          <dt className="text-xs uppercase tracking-[0.2em] text-slate-500">
            Payment
          </dt>
          <dd className="mt-1">{item.paymentStatusLabel}</dd>
        </div>
        <div>
          <dt className="text-xs uppercase tracking-[0.2em] text-slate-500">
            Total
          </dt>
          <dd className="mt-1">{item.grandTotalLabel}</dd>
        </div>
        <div>
          <dt className="text-xs uppercase tracking-[0.2em] text-slate-500">
            Placed
          </dt>
          <dd className="mt-1">{item.placedAtLabel}</dd>
        </div>
        <div>
          <dt className="text-xs uppercase tracking-[0.2em] text-slate-500">
            Items
          </dt>
          <dd className="mt-1">{item.itemCount}</dd>
        </div>
      </dl>
    </article>
  );
}

function statusTone(
  status: OrderListItem["status"],
): "success" | "danger" | "neutral" {
  if (status === "delivered") {
    return "success";
  }
  if (status === "cancelled" || status === "returned") {
    return "danger";
  }
  return "neutral";
}
