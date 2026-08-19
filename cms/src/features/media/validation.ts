import {
  MEDIA_ALT_INVALID_MESSAGE,
  MEDIA_REORDER_INVALID_MESSAGE,
  MEDIA_SORT_ORDER_INVALID_MESSAGE,
  MEDIA_VARIANT_INVALID_MESSAGE,
  PRODUCT_IMAGE_ALT_MAX_LENGTH,
  PRODUCT_IMAGE_MAX_COUNT,
  PRODUCT_IMAGE_SORT_ORDER_MAX,
  PRODUCT_IMAGE_SORT_ORDER_MIN,
  UUID_PATTERN,
} from "@/features/media/constants";
import { isValidUuid } from "@/features/products/validation";

export { isValidUuid };

export function normalizeOptionalMediaText(raw: string): string {
  return raw.trim().replace(/\s+/g, " ");
}

export function parseOptionalAltText(
  raw: unknown,
): { ok: true; value: string | null } | { ok: false; message: string } {
  if (raw === null || raw === undefined) {
    return { ok: true, value: null };
  }
  if (typeof raw !== "string") {
    return { ok: false, message: MEDIA_ALT_INVALID_MESSAGE };
  }
  const normalized = normalizeOptionalMediaText(raw);
  if (normalized.length === 0) {
    return { ok: true, value: null };
  }
  if (normalized.length > PRODUCT_IMAGE_ALT_MAX_LENGTH) {
    return { ok: false, message: MEDIA_ALT_INVALID_MESSAGE };
  }
  return { ok: true, value: normalized };
}

export function parseOptionalVariantId(
  raw: unknown,
): { ok: true; value: string | null } | { ok: false; message: string } {
  if (raw === null || raw === undefined) {
    return { ok: true, value: null };
  }
  if (typeof raw !== "string") {
    return { ok: false, message: MEDIA_VARIANT_INVALID_MESSAGE };
  }
  const trimmed = raw.trim();
  if (trimmed === "") {
    return { ok: true, value: null };
  }
  if (!isValidUuid(trimmed)) {
    return { ok: false, message: MEDIA_VARIANT_INVALID_MESSAGE };
  }
  return { ok: true, value: trimmed };
}

export function parseSortOrder(
  raw: unknown,
): { ok: true; value: number } | { ok: false; message: string } {
  if (typeof raw !== "string") {
    return { ok: false, message: MEDIA_SORT_ORDER_INVALID_MESSAGE };
  }
  const trimmed = raw.trim();
  if (!/^-?\d+$/.test(trimmed)) {
    return { ok: false, message: MEDIA_SORT_ORDER_INVALID_MESSAGE };
  }
  const value = Number.parseInt(trimmed, 10);
  if (
    !Number.isSafeInteger(value) ||
    value < PRODUCT_IMAGE_SORT_ORDER_MIN ||
    value > PRODUCT_IMAGE_SORT_ORDER_MAX
  ) {
    return { ok: false, message: MEDIA_SORT_ORDER_INVALID_MESSAGE };
  }
  return { ok: true, value };
}

export function parseCheckboxFlag(raw: unknown): boolean {
  if (typeof raw !== "string") {
    return false;
  }
  const normalized = raw.trim().toLowerCase();
  return (
    normalized === "on" ||
    normalized === "true" ||
    normalized === "1" ||
    normalized === "yes" ||
    normalized === "confirm"
  );
}

export function parseReorderImageIds(
  formData: FormData,
  expectedCount: number,
): { ok: true; imageIds: string[] } | { ok: false; message: string } {
  const raw = formData.getAll("image_ids");
  const imageIds: string[] = [];
  for (const value of raw) {
    if (typeof value !== "string") {
      return { ok: false, message: MEDIA_REORDER_INVALID_MESSAGE };
    }
    const trimmed = value.trim();
    if (!UUID_PATTERN.test(trimmed)) {
      return { ok: false, message: MEDIA_REORDER_INVALID_MESSAGE };
    }
    imageIds.push(trimmed);
  }

  if (
    imageIds.length === 0 ||
    imageIds.length > PRODUCT_IMAGE_MAX_COUNT ||
    imageIds.length !== expectedCount
  ) {
    return { ok: false, message: MEDIA_REORDER_INVALID_MESSAGE };
  }

  if (new Set(imageIds).size !== imageIds.length) {
    return { ok: false, message: MEDIA_REORDER_INVALID_MESSAGE };
  }

  return { ok: true, imageIds };
}

export function variantBelongsToProduct(
  variantId: string,
  allowedVariantIds: readonly string[],
): boolean {
  return allowedVariantIds.includes(variantId);
}
