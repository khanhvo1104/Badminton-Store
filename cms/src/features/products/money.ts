import { PRODUCT_NO_PRICE_LABEL } from "@/features/products/constants";

const DECIMAL_PATTERN = /^(?:0|[1-9]\d*)(?:\.\d{1,2})?$/;

export function parseSellingPrice(value: unknown): string | null {
  if (typeof value === "number") {
    if (!Number.isSafeInteger(value) || value < 0) {
      return null;
    }
    return String(value);
  }

  if (typeof value !== "string") {
    return null;
  }

  const trimmed = value.trim();
  if (!DECIMAL_PATTERN.test(trimmed)) {
    return null;
  }

  return trimmed;
}

export function sellingPriceToCents(amount: string): bigint {
  const [whole, fraction = ""] = amount.split(".");
  const paddedFraction = `${fraction}00`.slice(0, 2);
  return BigInt(whole) * BigInt(100) + BigInt(paddedFraction);
}

export function compareSellingPrices(left: string, right: string): number {
  const delta = sellingPriceToCents(left) - sellingPriceToCents(right);
  if (delta === BigInt(0)) {
    return 0;
  }
  return delta < BigInt(0) ? -1 : 1;
}

export function formatSellingPrice(amount: string): string {
  const [whole] = amount.split(".");
  const grouped = whole.replace(/\B(?=(\d{3})+(?!\d))/g, ".");
  return `${grouped}₫`;
}

export function formatPriceRange(
  minAmount: string | null,
  maxAmount: string | null,
): string {
  if (minAmount === null || maxAmount === null) {
    return PRODUCT_NO_PRICE_LABEL;
  }

  const minLabel = formatSellingPrice(minAmount);
  if (minAmount === maxAmount) {
    return minLabel;
  }

  return `${minLabel} – ${formatSellingPrice(maxAmount)}`;
}
