import { INVENTORY_SEARCH_MAX_LENGTH } from "@/features/inventory/constants";

export function normalizeInventorySearch(raw: string): string {
  const trimmed = raw.trim();
  if (!trimmed) {
    return "";
  }
  return trimmed.slice(0, INVENTORY_SEARCH_MAX_LENGTH);
}

export function sanitizeInventorySearchLiteral(raw: string): string {
  return normalizeInventorySearch(raw)
    .replaceAll("\\", "")
    .replaceAll("%", "")
    .replaceAll("_", "");
}
