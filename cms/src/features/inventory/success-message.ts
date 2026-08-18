import {
  INVENTORY_SAVE_SUCCESS_MESSAGE,
  INVENTORY_SUCCESS_ADJUSTED,
} from "@/features/inventory/constants";

export function inventorySuccessMessage(
  status: string | string[] | undefined,
): string | null {
  const value = Array.isArray(status) ? status[0] : status;
  return value === INVENTORY_SUCCESS_ADJUSTED
    ? INVENTORY_SAVE_SUCCESS_MESSAGE
    : null;
}
