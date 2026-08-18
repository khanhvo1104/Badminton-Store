import {
  PRODUCT_SPEC_INVALID_MESSAGE,
  PRODUCT_SPEC_MAX_KEY_LENGTH,
  PRODUCT_SPEC_MAX_KEYS,
  PRODUCT_SPEC_MAX_SERIALIZED_BYTES,
  PRODUCT_SPEC_MAX_STRING_VALUE_LENGTH,
} from "@/features/products/constants";

const FORBIDDEN_SPEC_KEYS = new Set(["__proto__", "prototype", "constructor"]);

export type SpecificationScalar = string | number | boolean | null;

export type ParsedSpecifications =
  | {
      ok: true;
      value: Record<string, SpecificationScalar>;
    }
  | { ok: false; message: string };

export function parseSpecificationsInput(raw: string): ParsedSpecifications {
  const trimmed = raw.trim();
  if (!trimmed) {
    return { ok: true, value: {} };
  }

  let parsed: unknown;
  try {
    parsed = JSON.parse(trimmed);
  } catch {
    return { ok: false, message: PRODUCT_SPEC_INVALID_MESSAGE };
  }

  if (!isPlainObject(parsed)) {
    return { ok: false, message: PRODUCT_SPEC_INVALID_MESSAGE };
  }

  const entries = Object.entries(parsed);
  if (entries.length > PRODUCT_SPEC_MAX_KEYS) {
    return { ok: false, message: PRODUCT_SPEC_INVALID_MESSAGE };
  }

  const normalized: Record<string, SpecificationScalar> = {};

  for (const [key, entryValue] of entries) {
    if (
      key.length === 0 ||
      key.length > PRODUCT_SPEC_MAX_KEY_LENGTH ||
      FORBIDDEN_SPEC_KEYS.has(key)
    ) {
      return { ok: false, message: PRODUCT_SPEC_INVALID_MESSAGE };
    }

    const scalar = normalizeSpecificationScalar(entryValue);
    if (!scalar.ok) {
      return scalar;
    }

    normalized[key] = scalar.value;
  }

  const serialized = JSON.stringify(normalized);
  if (serialized.length > PRODUCT_SPEC_MAX_SERIALIZED_BYTES) {
    return { ok: false, message: PRODUCT_SPEC_INVALID_MESSAGE };
  }

  return { ok: true, value: normalized };
}

export function formatSpecificationsForForm(
  value: Record<string, SpecificationScalar>,
): string {
  if (Object.keys(value).length === 0) {
    return "";
  }
  return JSON.stringify(value, null, 2);
}

function normalizeSpecificationScalar(
  value: unknown,
): { ok: true; value: SpecificationScalar } | { ok: false; message: string } {
  if (value === null) {
    return { ok: true, value: null };
  }

  if (typeof value === "boolean") {
    return { ok: true, value };
  }

  if (typeof value === "number") {
    if (!Number.isFinite(value)) {
      return { ok: false, message: PRODUCT_SPEC_INVALID_MESSAGE };
    }
    return { ok: true, value };
  }

  if (typeof value === "string") {
    if (value.length > PRODUCT_SPEC_MAX_STRING_VALUE_LENGTH) {
      return { ok: false, message: PRODUCT_SPEC_INVALID_MESSAGE };
    }
    return { ok: true, value };
  }

  return { ok: false, message: PRODUCT_SPEC_INVALID_MESSAGE };
}

function isPlainObject(value: unknown): value is Record<string, unknown> {
  if (typeof value !== "object" || value === null || Array.isArray(value)) {
    return false;
  }

  const prototype = Object.getPrototypeOf(value);
  return prototype === Object.prototype || prototype === null;
}
