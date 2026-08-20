import { ORDERS_SUCCESS_TRANSITIONED } from "@/features/orders/constants";
import { ORDERS_SAVE_SUCCESS_MESSAGE } from "@/features/orders/constants";

export function orderSuccessMessage(
  raw: string | string[] | undefined,
): string | null {
  const value = Array.isArray(raw) ? raw[0] : raw;
  if (value === ORDERS_SUCCESS_TRANSITIONED) {
    return ORDERS_SAVE_SUCCESS_MESSAGE;
  }
  return null;
}
