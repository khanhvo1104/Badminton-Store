import Link from "next/link";

import { INVENTORY_LIST_PATH } from "@/features/inventory/constants";
import { inventoryExplorerHref } from "@/features/inventory/validation";
import { ORDERS_LIST_PATH } from "@/features/orders/constants";
import { ordersExplorerHref } from "@/features/orders/validation";
import { DashboardRangeSelector } from "@/features/operational-dashboard/components/range-selector";
import type { OperationalDashboardSnapshot } from "@/features/operational-dashboard/types";

type OperationalDashboardProps = {
  snapshot: OperationalDashboardSnapshot;
  query: { rangeDays: OperationalDashboardSnapshot["rangeDays"] };
};

export function OperationalDashboard({
  snapshot,
  query,
}: OperationalDashboardProps) {
  return (
    <div className="space-y-8">
      <DashboardRangeSelector query={query} />

      <section aria-labelledby="dashboard-window-heading" className="space-y-2">
        <h2 id="dashboard-window-heading" className="sr-only">
          Selected reporting window
        </h2>
        <p className="text-sm leading-7 text-slate-300">
          Window: {snapshot.windowStartLabel} to {snapshot.windowEndLabel}{" "}
          (UTC). Order counts use placed_at in this window. Open fulfillment is
          the current global backlog, not windowed. Gross order value excludes
          cancelled and returned orders and is never summed across currencies.
        </p>
      </section>

      <section aria-labelledby="dashboard-kpi-heading" className="space-y-4">
        <h2
          id="dashboard-kpi-heading"
          className="text-xl font-semibold tracking-tight text-white"
        >
          Key metrics
        </h2>
        <dl className="grid gap-4 sm:grid-cols-2 xl:grid-cols-4">
          <MetricCard
            term="Total orders placed"
            description={`Orders with placed_at in the last ${snapshot.rangeDays} days.`}
            value={String(snapshot.totalOrders)}
            href={ORDERS_LIST_PATH}
          />
          <MetricCard
            term="Delivered orders"
            description="Delivered orders placed in the selected window."
            value={String(snapshot.deliveredOrders)}
            href={ordersExplorerHref({
              search: "",
              status: "delivered",
              paymentStatus: "all",
              sort: "placed_desc",
              placedFrom: null,
              placedTo: null,
              pagination: { page: 1, pageSize: 20 },
            })}
          />
          <MetricCard
            term="Open fulfillment backlog"
            description="Current pending, confirmed, preparing, or shipping orders."
            value={String(snapshot.openFulfillmentCount)}
            href={ordersExplorerHref({
              search: "",
              status: "pending",
              paymentStatus: "all",
              sort: "placed_desc",
              placedFrom: null,
              placedTo: null,
              pagination: { page: 1, pageSize: 20 },
            })}
          />
          <div className="rounded-3xl border border-white/10 bg-slate-900/70 p-5">
            <dt className="text-sm font-medium text-slate-300">
              Gross order value
            </dt>
            <dd className="mt-3 space-y-3">
              <div className="space-y-2">
                {snapshot.grossOrderValueByCurrency.length === 0 ? (
                  <p className="text-2xl font-semibold text-white">0</p>
                ) : (
                  snapshot.grossOrderValueByCurrency.map((entry) => (
                    <p
                      key={entry.currencyCode}
                      className="text-2xl font-semibold text-white"
                    >
                      {entry.grossOrderValueLabel}
                    </p>
                  ))
                )}
              </div>
              <p className="text-sm leading-6 text-slate-400">
                Non-cancelled, non-returned orders in the window, grouped by
                currency. Not recognized revenue.
              </p>
            </dd>
          </div>
        </dl>
      </section>

      <section aria-labelledby="dashboard-status-heading" className="space-y-4">
        <div className="flex flex-wrap items-end justify-between gap-3">
          <h2
            id="dashboard-status-heading"
            className="text-xl font-semibold tracking-tight text-white"
          >
            Status breakdown
          </h2>
          <Link
            href={ORDERS_LIST_PATH}
            className="text-sm font-medium text-emerald-300 hover:text-emerald-200"
          >
            View all orders
          </Link>
        </div>
        <div className="overflow-x-auto rounded-3xl border border-white/10 bg-slate-900/70">
          <table className="min-w-full text-left text-sm">
            <caption className="sr-only">
              Order counts by status for the selected placed_at window
            </caption>
            <thead className="border-b border-white/10 text-slate-300">
              <tr>
                <th scope="col" className="px-5 py-4 font-medium">
                  Status
                </th>
                <th scope="col" className="px-5 py-4 font-medium">
                  Orders
                </th>
              </tr>
            </thead>
            <tbody>
              {snapshot.statusBreakdown.map((item) => (
                <tr
                  key={item.status}
                  className="border-b border-white/5 last:border-b-0"
                >
                  <th scope="row" className="px-5 py-4 font-medium text-white">
                    <Link
                      href={ordersExplorerHref({
                        search: "",
                        status: item.status,
                        paymentStatus: "all",
                        sort: "placed_desc",
                        placedFrom: null,
                        placedTo: null,
                        pagination: { page: 1, pageSize: 20 },
                      })}
                      className="hover:text-emerald-200"
                    >
                      {item.statusLabel}
                    </Link>
                  </th>
                  <td className="px-5 py-4 text-slate-200">
                    {item.orderCount}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </section>

      <section aria-labelledby="dashboard-daily-heading" className="space-y-4">
        <h2
          id="dashboard-daily-heading"
          className="text-xl font-semibold tracking-tight text-white"
        >
          Daily activity
        </h2>
        {snapshot.dailySeriesByCurrency.length === 0 ? (
          <p className="rounded-3xl border border-dashed border-white/10 bg-slate-900/40 px-5 py-8 text-sm leading-7 text-slate-300">
            No orders were placed in the selected window.
          </p>
        ) : (
          snapshot.dailySeriesByCurrency.map((currencySeries) => (
            <div key={currencySeries.currencyCode} className="space-y-3">
              <h3 className="text-lg font-semibold text-white">
                {currencySeries.currencyCode} daily series
              </h3>
              <div className="overflow-x-auto rounded-3xl border border-white/10 bg-slate-900/70">
                <table className="min-w-full text-left text-sm">
                  <caption className="sr-only">
                    Daily order count and gross order value for{" "}
                    {currencySeries.currencyCode}
                  </caption>
                  <thead className="border-b border-white/10 text-slate-300">
                    <tr>
                      <th scope="col" className="px-5 py-4 font-medium">
                        UTC date
                      </th>
                      <th scope="col" className="px-5 py-4 font-medium">
                        Orders
                      </th>
                      <th scope="col" className="px-5 py-4 font-medium">
                        Gross order value
                      </th>
                    </tr>
                  </thead>
                  <tbody>
                    {currencySeries.series.map((point) => (
                      <tr
                        key={`${currencySeries.currencyCode}-${point.date}`}
                        className="border-b border-white/5 last:border-b-0"
                      >
                        <th
                          scope="row"
                          className="px-5 py-4 font-medium text-white"
                        >
                          {point.date}
                        </th>
                        <td className="px-5 py-4 text-slate-200">
                          {point.orderCount}
                        </td>
                        <td className="px-5 py-4 text-slate-200">
                          {point.grossOrderValueLabel}
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            </div>
          ))
        )}
      </section>

      <section
        aria-labelledby="dashboard-low-stock-heading"
        className="space-y-4"
      >
        <div className="flex flex-wrap items-end justify-between gap-3">
          <h2
            id="dashboard-low-stock-heading"
            className="text-xl font-semibold tracking-tight text-white"
          >
            Low-stock variants
          </h2>
          <Link
            href={inventoryExplorerHref({
              search: "",
              stock: "low_stock",
              sort: "available_asc",
              pagination: { page: 1, pageSize: 20 },
            })}
            className="text-sm font-medium text-emerald-300 hover:text-emerald-200"
          >
            View low-stock inventory
          </Link>
        </div>
        {snapshot.lowStockVariants.length === 0 ? (
          <p className="rounded-3xl border border-dashed border-white/10 bg-slate-900/40 px-5 py-8 text-sm leading-7 text-slate-300">
            No variants are currently at or below reorder level.
          </p>
        ) : (
          <div className="overflow-x-auto rounded-3xl border border-white/10 bg-slate-900/70">
            <table className="min-w-full text-left text-sm">
              <caption className="sr-only">
                Up to ten low-stock variants sorted by urgency
              </caption>
              <thead className="border-b border-white/10 text-slate-300">
                <tr>
                  <th scope="col" className="px-5 py-4 font-medium">
                    Product
                  </th>
                  <th scope="col" className="px-5 py-4 font-medium">
                    SKU
                  </th>
                  <th scope="col" className="px-5 py-4 font-medium">
                    On hand
                  </th>
                  <th scope="col" className="px-5 py-4 font-medium">
                    Reserved
                  </th>
                  <th scope="col" className="px-5 py-4 font-medium">
                    Available
                  </th>
                  <th scope="col" className="px-5 py-4 font-medium">
                    Reorder level
                  </th>
                  <th scope="col" className="px-5 py-4 font-medium">
                    Backorder
                  </th>
                </tr>
              </thead>
              <tbody>
                {snapshot.lowStockVariants.map((variant) => (
                  <tr
                    key={variant.variantId}
                    className="border-b border-white/5 last:border-b-0"
                  >
                    <th
                      scope="row"
                      className="px-5 py-4 font-medium text-white"
                    >
                      <Link
                        href={`${INVENTORY_LIST_PATH}/${variant.variantId}`}
                        className="hover:text-emerald-200"
                      >
                        {variant.productName}
                        {variant.variantName ? ` — ${variant.variantName}` : ""}
                      </Link>
                    </th>
                    <td className="px-5 py-4 text-slate-200">{variant.sku}</td>
                    <td className="px-5 py-4 text-slate-200">
                      {variant.quantityOnHand}
                    </td>
                    <td className="px-5 py-4 text-slate-200">
                      {variant.quantityReserved}
                    </td>
                    <td className="px-5 py-4 text-slate-200">
                      {variant.quantityAvailable}
                    </td>
                    <td className="px-5 py-4 text-slate-200">
                      {variant.reorderLevel}
                    </td>
                    <td className="px-5 py-4 text-slate-200">
                      {variant.allowBackorder ? "Allowed" : "No"}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </section>
    </div>
  );
}

type MetricCardProps = {
  term: string;
  description: string;
  value: string;
  href: string;
};

function MetricCard({ term, description, value, href }: MetricCardProps) {
  return (
    <div className="rounded-3xl border border-white/10 bg-slate-900/70 p-5">
      <dt className="text-sm font-medium text-slate-300">{term}</dt>
      <dd className="mt-3 space-y-3">
        <Link
          href={href}
          className="block text-3xl font-semibold text-white hover:text-emerald-200"
        >
          {value}
        </Link>
        <p className="text-sm leading-6 text-slate-400">{description}</p>
      </dd>
    </div>
  );
}
