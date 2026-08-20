import { revalidatePath } from "next/cache";

import { ORDERS_LIST_PATH, orderDetailPath } from "@/features/orders/constants";

export function getOrderRevalidationPaths(orderId: string): string[] {
  return [ORDERS_LIST_PATH, orderDetailPath(orderId)];
}

export function revalidateOrderPaths(orderId: string): void {
  for (const path of getOrderRevalidationPaths(orderId)) {
    revalidatePath(path);
  }
}
