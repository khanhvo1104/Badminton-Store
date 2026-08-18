import Link from "next/link";

import { EmptyState } from "@/components/ui/empty-state";
import { PRODUCTS_LIST_PATH } from "@/features/products/constants";

export default function ProductNotFound() {
  return (
    <div className="mx-auto max-w-3xl">
      <EmptyState
        title="Product not found"
        description="That product could not be found, or you no longer have access to it."
        action={
          <Link
            href={PRODUCTS_LIST_PATH}
            className="inline-flex rounded-full bg-emerald-300 px-5 py-3 text-sm font-semibold text-slate-950 transition hover:bg-emerald-200 focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-emerald-200"
          >
            Back to products
          </Link>
        }
      />
    </div>
  );
}
