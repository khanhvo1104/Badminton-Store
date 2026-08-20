import Link from "next/link";
import { notFound } from "next/navigation";

import { ErrorState } from "@/components/ui/error-state";
import { StatusBadge } from "@/components/ui/status-badge";
import { OrderTransitionForm } from "@/features/orders/components/order-transition-form";
import { ORDERS_LIST_PATH } from "@/features/orders/constants";
import {
  getOrderDetail,
  type OrdersQueryClient,
} from "@/features/orders/queries";
import { orderSuccessMessage } from "@/features/orders/success-message";
import type { OrderDetail } from "@/features/orders/types";
import { isValidUuid } from "@/features/products/validation";
import { createSupabaseServerClient } from "@/lib/supabase/server";

export const dynamic = "force-dynamic";

type OrderDetailPageProps = {
  params: Promise<{ orderId: string }>;
  searchParams?: Promise<Record<string, string | string[] | undefined>>;
};

export default async function OrderDetailPage({
  params,
  searchParams,
}: OrderDetailPageProps) {
  const { orderId } = await params;
  const resolvedSearchParams = (await searchParams) ?? {};

  if (!isValidUuid(orderId)) {
    notFound();
  }

  const supabase = await createSupabaseServerClient();
  const result = await getOrderDetail({
    supabase: supabase as unknown as OrdersQueryClient,
    orderId,
  });

  if (!result.ok && result.notFound) {
    notFound();
  }

  if (!result.ok) {
    return (
      <div className="mx-auto max-w-3xl">
        <ErrorState title="Unable to load order" description={result.message} />
      </div>
    );
  }

  const successMessage = orderSuccessMessage(resolvedSearchParams.success);

  return (
    <div className="mx-auto max-w-4xl space-y-8">
      <header className="space-y-3">
        <p className="text-sm font-semibold uppercase tracking-[0.3em] text-emerald-300">
          Orders
        </p>
        <h1 className="text-3xl font-semibold tracking-tight text-white sm:text-4xl">
          {result.detail.orderNumber}
        </h1>
        <p className="max-w-2xl text-base leading-7 text-slate-300">
          Review trusted totals, shipping snapshot, line items, and append-only
          status history. Status changes run through the atomic transition
          action.
        </p>
        <Link
          href={ORDERS_LIST_PATH}
          className="inline-flex font-semibold text-emerald-200 underline-offset-4 hover:underline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-emerald-200"
        >
          Back to orders
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

      <OrderSummary detail={result.detail} />
      <ShippingSnapshot detail={result.detail} />
      <ItemsList detail={result.detail} />
      <OrderTransitionForm
        orderId={orderId}
        currentStatus={result.detail.status}
        nextStatuses={result.detail.nextStatuses}
      />
      <HistoryList detail={result.detail} />
    </div>
  );
}

function OrderSummary({ detail }: { detail: OrderDetail }) {
  return (
    <section
      aria-labelledby="order-summary-heading"
      className="space-y-4 rounded-3xl border border-white/10 bg-slate-900/60 p-5"
    >
      <h2
        id="order-summary-heading"
        className="text-lg font-semibold text-white"
      >
        Order summary
      </h2>
      <dl className="grid gap-4 sm:grid-cols-2 text-sm text-slate-300">
        <Info label="Recipient" value={detail.recipientName} />
        <Info label="Phone" value={detail.recipientPhone} />
        <div>
          <dt className="text-xs uppercase tracking-[0.2em] text-slate-500">
            Status
          </dt>
          <dd className="mt-1">
            <StatusBadge tone={statusTone(detail.status)}>
              {detail.statusLabel}
            </StatusBadge>
          </dd>
        </div>
        <Info label="Payment status" value={detail.paymentStatusLabel} />
        <Info
          label="Payment method"
          value={detail.paymentMethod.toUpperCase()}
        />
        <Info label="Placed" value={detail.placedAtLabel} />
        <Info label="Subtotal" value={detail.subtotalLabel} />
        <Info label="Discount" value={detail.discountTotalLabel} />
        <Info label="Shipping fee" value={detail.shippingFeeLabel} />
        <Info label="Grand total" value={detail.grandTotalLabel} />
        {detail.cancelledAtLabel ? (
          <Info label="Cancelled" value={detail.cancelledAtLabel} />
        ) : null}
        {detail.customerNote ? (
          <Info label="Customer note" value={detail.customerNote} />
        ) : null}
      </dl>
    </section>
  );
}

function ShippingSnapshot({ detail }: { detail: OrderDetail }) {
  const shipping = detail.shipping;
  return (
    <section
      aria-labelledby="shipping-heading"
      className="space-y-4 rounded-3xl border border-white/10 bg-slate-900/60 p-5"
    >
      <h2 id="shipping-heading" className="text-lg font-semibold text-white">
        Shipping snapshot
      </h2>
      <dl className="grid gap-4 sm:grid-cols-2 text-sm text-slate-300">
        <Info
          label="Recipient"
          value={shipping.recipientName ?? detail.recipientName}
        />
        <Info
          label="Phone"
          value={shipping.phoneNumber ?? detail.recipientPhone}
        />
        <Info label="Province" value={shipping.provinceName ?? "—"} />
        <Info label="District" value={shipping.districtName ?? "—"} />
        <Info label="Ward" value={shipping.wardName ?? "—"} />
        <Info label="Street" value={shipping.streetAddress ?? "—"} />
        <Info label="Address note" value={shipping.addressNote ?? "—"} />
      </dl>
    </section>
  );
}

function ItemsList({ detail }: { detail: OrderDetail }) {
  return (
    <section aria-labelledby="items-heading" className="space-y-4">
      <h2 id="items-heading" className="text-lg font-semibold text-white">
        Line items
      </h2>
      {detail.items.length === 0 ? (
        <p className="text-sm text-slate-400">No line items on this order.</p>
      ) : (
        <ul className="space-y-3">
          {detail.items.map((item) => (
            <li
              key={item.id}
              className="rounded-3xl border border-white/10 bg-slate-900/60 p-4 text-sm text-slate-300"
            >
              <p className="font-semibold text-white">{item.productName}</p>
              <p className="mt-1 text-xs text-slate-400">
                {item.variantName ?? "Variant"} · {item.sku}
              </p>
              <p className="mt-2">
                {item.quantity} × {item.unitPriceLabel} = {item.lineTotalLabel}
              </p>
            </li>
          ))}
        </ul>
      )}
    </section>
  );
}

function HistoryList({ detail }: { detail: OrderDetail }) {
  return (
    <section aria-labelledby="history-heading" className="space-y-4">
      <h2 id="history-heading" className="text-lg font-semibold text-white">
        Status history
      </h2>
      {detail.history.length === 0 ? (
        <p className="text-sm text-slate-400">
          No status history recorded yet.
        </p>
      ) : (
        <ol className="space-y-3">
          {detail.history.map((item) => (
            <li
              key={item.id}
              className="rounded-3xl border border-white/10 bg-slate-900/60 p-4 text-sm text-slate-300"
            >
              <p className="font-semibold text-white">
                {item.fromStatusLabel ?? "Created"} → {item.toStatusLabel}
              </p>
              <p className="mt-1 text-xs text-slate-400">
                {item.createdAtLabel} · {item.actorName}
              </p>
              {item.note ? <p className="mt-2">{item.note}</p> : null}
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

function statusTone(
  status: OrderDetail["status"],
): "success" | "danger" | "neutral" {
  if (status === "delivered") {
    return "success";
  }
  if (status === "cancelled" || status === "returned") {
    return "danger";
  }
  return "neutral";
}
