import {
  BRAND_GENERIC_FAILURE_MESSAGE,
  BRAND_SLUG_CONFLICT_MESSAGE,
} from "@/features/brands/constants";

export {
  BRAND_AUTH_DENIED_MESSAGE,
  BRAND_GENERIC_FAILURE_MESSAGE,
  BRAND_LOAD_FAILURE_MESSAGE,
  BRAND_NOT_FOUND_MESSAGE,
  BRAND_SLUG_CONFLICT_MESSAGE,
  BRAND_WEBSITE_INVALID_MESSAGE,
  BRAND_LOGO_INVALID_MESSAGE,
  BRAND_LOGO_UPLOAD_FAILURE_MESSAGE,
  BRAND_LOGO_CLEANUP_WARNING,
  BRAND_ACTIVATION_CONFIRM_REQUIRED_MESSAGE,
  BRAND_ACTIVATION_SUCCESS_ACTIVE,
  BRAND_ACTIVATION_SUCCESS_INACTIVE,
  BRAND_SAVE_SUCCESS_MESSAGE,
} from "@/features/brands/constants";

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
    message.includes("brands_slug_unique")
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

  return details.includes("slug") || details.includes("brands_slug");
}

export function isSlugConflictError(error: unknown): boolean {
  return isSlugUniqueViolation(error);
}

export function toBrandMutationFailureMessage(error: unknown): string {
  if (isSlugUniqueViolation(error)) {
    return BRAND_SLUG_CONFLICT_MESSAGE;
  }
  return BRAND_GENERIC_FAILURE_MESSAGE;
}

export function sanitizeBrandProviderError(error: unknown): string {
  return toBrandMutationFailureMessage(error);
}

export function sanitizeProviderError(error: unknown): string {
  void error;
  return BRAND_GENERIC_FAILURE_MESSAGE;
}

export function assertNoProviderLeak(message: string): boolean {
  return !PROVIDER_LEAK_PATTERN.test(message);
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null;
}
