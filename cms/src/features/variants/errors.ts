import {
  VARIANT_BARCODE_CONFLICT_MESSAGE,
  VARIANT_GENERIC_FAILURE_MESSAGE,
  VARIANT_LOAD_FAILURE_MESSAGE,
  VARIANT_SKU_CONFLICT_MESSAGE,
} from "@/features/variants/constants";

const PROVIDER_LEAK_PATTERN =
  /\b(sql|postgrest|permission denied|row-level|rls|jwt|token|stack|exception|storage\.objects|violates|duplicate key|23505|PGRST)\b/i;

export function isUniqueViolation(error: unknown): boolean {
  if (!isRecord(error)) {
    return false;
  }
  if (error.code === "23505") {
    return true;
  }
  const message =
    typeof error.message === "string" ? error.message.toLowerCase() : "";
  return (
    message.includes("duplicate key") || message.includes("unique constraint")
  );
}

export function isSkuUniqueViolation(error: unknown): boolean {
  if (!isUniqueViolation(error)) {
    return false;
  }
  const details = uniqueDetails(error);
  if (!details) {
    return true;
  }
  if (details.includes("barcode")) {
    return false;
  }
  return details.includes("sku") || details.includes("product_variants_sku");
}

export function isBarcodeUniqueViolation(error: unknown): boolean {
  if (!isUniqueViolation(error)) {
    return false;
  }
  const details = uniqueDetails(error);
  return details.includes("barcode");
}

export function toVariantMutationFailureMessage(error: unknown): string {
  if (isSkuUniqueViolation(error)) {
    return VARIANT_SKU_CONFLICT_MESSAGE;
  }
  if (isBarcodeUniqueViolation(error)) {
    return VARIANT_BARCODE_CONFLICT_MESSAGE;
  }
  return VARIANT_GENERIC_FAILURE_MESSAGE;
}

export function variantMutationFieldErrors(
  error: unknown,
  message: string,
): { sku?: string; barcode?: string } {
  if (isSkuUniqueViolation(error)) {
    return { sku: message };
  }
  if (isBarcodeUniqueViolation(error)) {
    return { barcode: message };
  }
  return {};
}

export function isNotFoundError(error: unknown): boolean {
  if (!isRecord(error)) {
    return false;
  }
  const code = typeof error.code === "string" ? error.code : "";
  const message =
    typeof error.message === "string" ? error.message.toLowerCase() : "";
  return (
    code === "P0002" ||
    code === "PGRST116" ||
    code === "02000" ||
    message === "not found"
  );
}

export function sanitizeVariantProviderError(error: unknown): string {
  void error;
  return VARIANT_LOAD_FAILURE_MESSAGE;
}

export function assertNoProviderLeak(message: string): boolean {
  return !PROVIDER_LEAK_PATTERN.test(message);
}

function uniqueDetails(error: unknown): string {
  if (!isRecord(error)) {
    return "";
  }
  return [error.message, error.details, error.hint, error.constraint]
    .filter((value): value is string => typeof value === "string")
    .join(" ")
    .toLowerCase();
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null;
}
