import { revalidatePath } from "next/cache";

import {
  INVENTORY_LIST_PATH,
  inventoryAdjustmentPath,
} from "@/features/inventory/constants";

export function getInventoryRevalidationPaths(variantId: string): string[] {
  return [INVENTORY_LIST_PATH, inventoryAdjustmentPath(variantId)];
}

export function revalidateInventoryPaths(variantId: string): void {
  for (const path of getInventoryRevalidationPaths(variantId)) {
    revalidatePath(path);
  }
}
