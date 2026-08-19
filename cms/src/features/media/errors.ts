import {
  MEDIA_GENERIC_FAILURE_MESSAGE,
  MEDIA_LOAD_FAILURE_MESSAGE,
  MEDIA_NOT_FOUND_MESSAGE,
} from "@/features/media/constants";

export {
  MEDIA_AUTH_DENIED_MESSAGE,
  MEDIA_GENERIC_FAILURE_MESSAGE,
  MEDIA_LOAD_FAILURE_MESSAGE,
  MEDIA_NOT_FOUND_MESSAGE,
  MEDIA_PRODUCT_NOT_FOUND_MESSAGE,
  MEDIA_IMAGE_INVALID_MESSAGE,
  MEDIA_IMAGE_REQUIRED_MESSAGE,
  MEDIA_IMAGE_UPLOAD_FAILURE_MESSAGE,
  MEDIA_IMAGE_CLEANUP_WARNING,
  MEDIA_DELETE_CLEANUP_WARNING,
  MEDIA_COUNT_LIMIT_MESSAGE,
  MEDIA_ALT_INVALID_MESSAGE,
  MEDIA_VARIANT_INVALID_MESSAGE,
  MEDIA_SORT_ORDER_INVALID_MESSAGE,
  MEDIA_REORDER_INVALID_MESSAGE,
  MEDIA_DELETE_CONFIRM_REQUIRED_MESSAGE,
} from "@/features/media/constants";

const PROVIDER_LEAK_PATTERN =
  /\b(sql|postgrest|permission denied|row-level|rls|jwt|token|stack|exception|storage\.objects|violates|duplicate key|23505|PGRST)\b/i;

export function toMediaMutationFailureMessage(error: unknown): string {
  void error;
  return MEDIA_GENERIC_FAILURE_MESSAGE;
}

export function sanitizeMediaProviderError(error: unknown): string {
  void error;
  return MEDIA_LOAD_FAILURE_MESSAGE;
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

export function isInvalidRequestError(error: unknown): boolean {
  if (!isRecord(error)) {
    return false;
  }
  const code = typeof error.code === "string" ? error.code : "";
  const message =
    typeof error.message === "string" ? error.message.toLowerCase() : "";
  return code === "22023" || message === "invalid request";
}

export function isInvalidVariantError(error: unknown): boolean {
  if (!isRecord(error)) {
    return false;
  }
  const message =
    typeof error.message === "string" ? error.message.toLowerCase() : "";
  return message === "invalid variant";
}

export function isImageLimitError(error: unknown): boolean {
  if (!isRecord(error)) {
    return false;
  }
  const message =
    typeof error.message === "string" ? error.message.toLowerCase() : "";
  return message === "image limit exceeded";
}

export function assertNoProviderLeak(message: string): boolean {
  return !PROVIDER_LEAK_PATTERN.test(message);
}

export function mediaNotFoundOrGeneric(error: unknown): string {
  if (isNotFoundError(error)) {
    return MEDIA_NOT_FOUND_MESSAGE;
  }
  return MEDIA_GENERIC_FAILURE_MESSAGE;
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null;
}
