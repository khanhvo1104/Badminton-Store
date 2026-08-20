import Link from "next/link";

import { ORDERS_LIST_PATH } from "@/features/orders/constants";

export default function OrderNotFound() {
  return (
    <div className="mx-auto max-w-3xl space-y-4 rounded-3xl border border-white/10 bg-slate-900/60 p-8">
      <h1 className="text-2xl font-semibold text-white">Order not found</h1>
      <p className="text-sm leading-7 text-slate-300">
        That order does not exist or is not available in the CMS.
      </p>
      <Link
        href={ORDERS_LIST_PATH}
        className="inline-flex font-semibold text-emerald-200 underline-offset-4 hover:underline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-emerald-200"
      >
        Back to orders
      </Link>
    </div>
  );
}
