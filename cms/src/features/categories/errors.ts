import {
  CATEGORY_GENERIC_FAILURE_MESSAGE,
  CATEGORY_SLUG_CONFLICT_MESSAGE,
} from "@/features/categories/constants";

export {
  CATEGORY_AUTH_DENIED_MESSAGE,
  CATEGORY_GENERIC_FAILURE_MESSAGE,
  CATEGORY_LOAD_FAILURE_MESSAGE,
  CATEGORY_NOT_FOUND_MESSAGE,
  CATEGORY_SLUG_CONFLICT_MESSAGE,
  CATEGORY_PARENT_INVALID_MESSAGE,
  CATEGORY_PARENT_CYCLE_MESSAGE,
  CATEGORY_IMAGE_INVALID_MESSAGE,
  CATEGORY_IMAGE_UPLOAD_FAILURE_MESSAGE,
  CATEGORY_IMAGE_CLEANUP_WARNING,
  CATEGORY_ACTIVATION_CONFIRM_REQUIRED_MESSAGE,
  CATEGORY_ACTIVATION_SUCCESS_ACTIVE,
  CATEGORY_ACTIVATION_SUCCESS_INACTIVE,
  CATEGORY_SAVE_SUCCESS_MESSAGE,
} from "@/features/categories/constants";

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
    message.includes("categories_slug_unique")
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

  return details.includes("slug") || details.includes("categories_slug");
}

export function isSlugConflictError(error: unknown): boolean {
  return isSlugUniqueViolation(error);
}

export function toCategoryMutationFailureMessage(error: unknown): string {
  if (isSlugUniqueViolation(error)) {
    return CATEGORY_SLUG_CONFLICT_MESSAGE;
  }
  return CATEGORY_GENERIC_FAILURE_MESSAGE;
}

export function sanitizeCategoryProviderError(error: unknown): string {
  return toCategoryMutationFailureMessage(error);
}

export function sanitizeProviderError(error: unknown): string {
  void error;
  return CATEGORY_GENERIC_FAILURE_MESSAGE;
}

export function assertNoProviderLeak(message: string): boolean {
  return !PROVIDER_LEAK_PATTERN.test(message);
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null;
}
