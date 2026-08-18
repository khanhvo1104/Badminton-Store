import Link from "next/link";

import { EmptyState } from "@/components/ui/empty-state";
import { INVENTORY_LIST_PATH } from "@/features/inventory/constants";

export default function InventoryAdjustmentNotFound() {
  return (
    <div className="mx-auto max-w-3xl">
      <EmptyState
        title="Variant not found"
        description="That variant could not be found, or you no longer have access to it."
        action={
          <Link
            href={INVENTORY_LIST_PATH}
            className="inline-flex rounded-full bg-emerald-300 px-5 py-3 text-sm font-semibold text-slate-950 transition hover:bg-emerald-200 focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-emerald-200"
          >
            Back to inventory
          </Link>
        }
      />
    </div>
  );
}
