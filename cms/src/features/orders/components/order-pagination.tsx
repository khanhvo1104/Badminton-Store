import Link from "next/link";

import type { OrdersListResult } from "@/features/orders/types";
import { ordersExplorerHref } from "@/features/orders/validation";

type OrderPaginationProps = {
  result: OrdersListResult;
};

export function OrderPagination({ result }: OrderPaginationProps) {
  if (result.totalPages <= 1) {
    return null;
  }

  const { page, pageSize } = result.pagination;
  const prevHref =
    page > 1
      ? ordersExplorerHref({
          ...result.query,
          pagination: { page: page - 1, pageSize },
        })
      : null;
  const nextHref =
    page < result.totalPages
      ? ordersExplorerHref({
          ...result.query,
          pagination: { page: page + 1, pageSize },
        })
      : null;

  return (
    <nav
      aria-label="Orders pagination"
      className="flex flex-wrap items-center justify-between gap-3 text-sm text-slate-300"
    >
      <p>
        Page {page} of {result.totalPages} · {result.totalCount} orders
      </p>
      <div className="flex gap-3">
        {prevHref ? (
          <Link
            href={prevHref}
            className="rounded-full border border-white/15 px-4 py-2 font-semibold text-white transition hover:border-white/30 hover:bg-white/5 focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-emerald-200"
          >
            Previous
          </Link>
        ) : (
          <span className="rounded-full border border-white/5 px-4 py-2 text-slate-500">
            Previous
          </span>
        )}
        {nextHref ? (
          <Link
            href={nextHref}
            className="rounded-full border border-white/15 px-4 py-2 font-semibold text-white transition hover:border-white/30 hover:bg-white/5 focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-emerald-200"
          >
            Next
          </Link>
        ) : (
          <span className="rounded-full border border-white/5 px-4 py-2 text-slate-500">
            Next
          </span>
        )}
      </div>
    </nav>
  );
}
