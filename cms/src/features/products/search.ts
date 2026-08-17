import { PRODUCT_SEARCH_MAX_LENGTH } from "@/features/products/constants";

export type ProductSearchPlan =
  | { kind: "none" }
  | { kind: "none-match" }
  | { kind: "or"; filter: string; literal: string };

export function normalizeProductSearch(raw: string): string {
  const trimmed = raw.trim();
  if (!trimmed) {
    return "";
  }
  return trimmed.slice(0, PRODUCT_SEARCH_MAX_LENGTH);
}

export function sanitizeProductSearchLiteral(raw: string): string {
  return normalizeProductSearch(raw)
    .replaceAll("\\", "")
    .replaceAll("%", "")
    .replaceAll("_", "");
}

export function quotePostgrestValue(value: string): string {
  return `"${value.replaceAll('"', '""')}"`;
}

export function buildProductSearchOrFilter(literal: string): string {
  const pattern = quotePostgrestValue(`%${literal}%`);
  return `name.ilike.${pattern},slug.ilike.${pattern}`;
}

export function planProductSearch(raw: string): ProductSearchPlan {
  const normalized = normalizeProductSearch(raw);
  if (!normalized) {
    return { kind: "none" };
  }

  const literal = sanitizeProductSearchLiteral(normalized);
  if (!literal) {
    return { kind: "none-match" };
  }

  return {
    kind: "or",
    filter: buildProductSearchOrFilter(literal),
    literal,
  };
}
