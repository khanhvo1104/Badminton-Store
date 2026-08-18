import { VARIANT_MONEY_PATTERN } from "@/features/variants/constants";
import {
  sellingPriceToCents,
  formatSellingPrice,
} from "@/features/products/money";

export { formatSellingPrice, sellingPriceToCents };

export function parseVariantMoney(value: unknown): string | null {
  if (typeof value === "number") {
    if (!Number.isFinite(value) || value < 0) {
      return null;
    }
    if (Number.isSafeInteger(value)) {
      return String(value);
    }
    const rendered = String(value);
    if (!VARIANT_MONEY_PATTERN.test(rendered)) {
      return null;
    }
    return rendered;
  }

  if (typeof value !== "string") {
    return null;
  }

  const trimmed = value.trim();
  if (!VARIANT_MONEY_PATTERN.test(trimmed)) {
    return null;
  }
  return trimmed;
}

export function compareVariantMoney(left: string, right: string): number {
  const delta = sellingPriceToCents(left) - sellingPriceToCents(right);
  if (delta === BigInt(0)) {
    return 0;
  }
  return delta < BigInt(0) ? -1 : 1;
}
