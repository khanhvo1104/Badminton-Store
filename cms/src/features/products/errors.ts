import {
  PRODUCT_GENERIC_FAILURE_MESSAGE,
  PRODUCT_LOAD_FAILURE_MESSAGE,
  PRODUCT_SLUG_CONFLICT_MESSAGE,
} from "@/features/products/constants";

export {
  PRODUCT_AUTH_DENIED_MESSAGE,
  PRODUCT_LOAD_FAILURE_MESSAGE,
  PRODUCT_MUTATION_AUTH_DENIED_MESSAGE,
  PRODUCT_GENERIC_FAILURE_MESSAGE,
  PRODUCT_NOT_FOUND_MESSAGE,
  PRODUCT_SLUG_CONFLICT_MESSAGE,
  PRODUCT_INACTIVE_CATEGORY_MESSAGE,
  PRODUCT_INACTIVE_BRAND_MESSAGE,
  PRODUCT_CATEGORY_REQUIRED_MESSAGE,
  PRODUCT_PUBLISH_INACTIVE_CATEGORY_MESSAGE,
  PRODUCT_SPEC_INVALID_MESSAGE,
  PRODUCT_PUBLISHED_AT_INVALID_MESSAGE,
  PRODUCT_SAVE_SUCCESS_MESSAGE,
} from "@/features/products/constants";

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
    message.includes("duplicate key") ||
    message.includes("unique constraint") ||
    message.includes("products_slug_unique")
  );
}

export function isSlugUniqueViolation(error: unknown): boolean {
  if (!isUniqueViolation(error)) {
    return false;
  }

  if (!isRecord(error)) {
    return true;
  }

  const details = [error.message, error.details, error.hint, error.constraint]
    .filter((value): value is string => typeof value === "string")
    .join(" ")
    .toLowerCase();

  if (!details) {
    return true;
  }

  return details.includes("slug") || details.includes("products_slug");
}

export function toProductMutationFailureMessage(error: unknown): string {
  if (isSlugUniqueViolation(error)) {
    return PRODUCT_SLUG_CONFLICT_MESSAGE;
  }
  return PRODUCT_GENERIC_FAILURE_MESSAGE;
}

export function sanitizeProductProviderError(error: unknown): string {
  void error;
  return PRODUCT_LOAD_FAILURE_MESSAGE;
}

export function assertNoProviderLeak(message: string): boolean {
  return !PROVIDER_LEAK_PATTERN.test(message);
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null;
}
