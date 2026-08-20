import { ORDERS_SEARCH_MAX_LENGTH } from "@/features/orders/constants";

export function normalizeOrdersSearch(raw: string): string {
  const trimmed = raw.trim();
  if (!trimmed) {
    return "";
  }
  return trimmed.slice(0, ORDERS_SEARCH_MAX_LENGTH);
}

export function sanitizeOrdersSearchLiteral(raw: string): string {
  return normalizeOrdersSearch(raw)
    .replaceAll("\\", "")
    .replaceAll("%", "")
    .replaceAll("_", "");
}
