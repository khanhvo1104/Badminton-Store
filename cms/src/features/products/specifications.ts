import {
  PRODUCT_SPEC_INVALID_MESSAGE,
  PRODUCT_SPEC_MAX_DEPTH,
  PRODUCT_SPEC_MAX_KEY_LENGTH,
  PRODUCT_SPEC_MAX_KEYS,
  PRODUCT_SPEC_MAX_SERIALIZED_BYTES,
  PRODUCT_SPEC_MAX_STRING_VALUE_LENGTH,
} from "@/features/products/constants";

const FORBIDDEN_SPEC_KEYS = new Set(["__proto__", "prototype", "constructor"]);

export type SpecificationScalar = string | number | boolean | null;

export type SpecificationObject = {
  [key: string]: SpecificationValue;
};

export type SpecificationValue = SpecificationScalar | SpecificationObject;

export type SpecificationsJson = SpecificationObject;

export type ParsedSpecifications =
  | {
      ok: true;
      value: SpecificationsJson;
    }
  | { ok: false; message: string };

type SpecificationMetrics = {
  keyCount: number;
};

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

  return normalizeSpecificationsRoot(parsed);
}

export function parseSpecificationsValue(
  value: unknown,
): SpecificationsJson | null {
  const parsed = normalizeSpecificationsRoot(value);
  return parsed.ok ? parsed.value : null;
}

export function formatSpecificationsForForm(value: SpecificationsJson): string {
  if (Object.keys(value).length === 0) {
    return "";
  }
  return JSON.stringify(value, null, 2);
}

function normalizeSpecificationsRoot(value: unknown): ParsedSpecifications {
  if (!isPlainObject(value)) {
    return { ok: false, message: PRODUCT_SPEC_INVALID_MESSAGE };
  }

  const metrics: SpecificationMetrics = { keyCount: 0 };
  const normalized = normalizeSpecificationNode(value, 1, metrics);
  if (!normalized.ok) {
    return normalized;
  }

  if (!isPlainObject(normalized.value)) {
    return { ok: false, message: PRODUCT_SPEC_INVALID_MESSAGE };
  }

  const serialized = JSON.stringify(normalized.value);
  if (serialized.length > PRODUCT_SPEC_MAX_SERIALIZED_BYTES) {
    return { ok: false, message: PRODUCT_SPEC_INVALID_MESSAGE };
  }

  return { ok: true, value: normalized.value };
}

function normalizeSpecificationNode(
  value: unknown,
  depth: number,
  metrics: SpecificationMetrics,
): { ok: true; value: SpecificationValue } | { ok: false; message: string } {
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

  if (Array.isArray(value)) {
    return { ok: false, message: PRODUCT_SPEC_INVALID_MESSAGE };
  }

  if (!isPlainObject(value)) {
    return { ok: false, message: PRODUCT_SPEC_INVALID_MESSAGE };
  }

  if (depth > PRODUCT_SPEC_MAX_DEPTH) {
    return { ok: false, message: PRODUCT_SPEC_INVALID_MESSAGE };
  }

  const normalized: SpecificationObject = {};
  for (const [key, entryValue] of Object.entries(value)) {
    if (
      key.length === 0 ||
      key.length > PRODUCT_SPEC_MAX_KEY_LENGTH ||
      FORBIDDEN_SPEC_KEYS.has(key)
    ) {
      return { ok: false, message: PRODUCT_SPEC_INVALID_MESSAGE };
    }

    metrics.keyCount += 1;
    if (metrics.keyCount > PRODUCT_SPEC_MAX_KEYS) {
      return { ok: false, message: PRODUCT_SPEC_INVALID_MESSAGE };
    }

    const parsedChild = normalizeSpecificationNode(
      entryValue,
      depth + 1,
      metrics,
    );
    if (!parsedChild.ok) {
      return parsedChild;
    }

    normalized[key] = parsedChild.value;
  }

  return { ok: true, value: normalized };
}

function isPlainObject(value: unknown): value is Record<string, unknown> {
  if (typeof value !== "object" || value === null || Array.isArray(value)) {
    return false;
  }

  const prototype = Object.getPrototypeOf(value);
  return prototype === Object.prototype || prototype === null;
}
