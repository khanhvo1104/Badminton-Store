import {
  VARIANT_ATTRIBUTES_INVALID_MESSAGE,
  VARIANT_ATTR_MAX_DEPTH,
  VARIANT_ATTR_MAX_KEY_LENGTH,
  VARIANT_ATTR_MAX_KEYS,
  VARIANT_ATTR_MAX_SERIALIZED_BYTES,
  VARIANT_ATTR_MAX_STRING_VALUE_LENGTH,
} from "@/features/variants/constants";

const FORBIDDEN_ATTR_KEYS = new Set(["__proto__", "prototype", "constructor"]);

export type VariantAttributeScalar = string | number | boolean | null;
export type VariantAttributeObject = {
  [key: string]: VariantAttributeValue;
};
export type VariantAttributeValue =
  | VariantAttributeScalar
  | VariantAttributeObject;
export type VariantAttributesJson = VariantAttributeObject;

export type ParsedVariantAttributes =
  | { ok: true; value: VariantAttributesJson }
  | { ok: false; message: string };

type AttributeMetrics = {
  keyCount: number;
};

export function parseVariantAttributesInput(
  raw: string,
): ParsedVariantAttributes {
  const trimmed = raw.trim();
  if (!trimmed) {
    return { ok: true, value: {} };
  }

  let parsed: unknown;
  try {
    parsed = JSON.parse(trimmed);
  } catch {
    return { ok: false, message: VARIANT_ATTRIBUTES_INVALID_MESSAGE };
  }

  return normalizeAttributesRoot(parsed);
}

export function parseVariantAttributesValue(
  value: unknown,
): VariantAttributesJson | null {
  const parsed = normalizeAttributesRoot(value);
  return parsed.ok ? parsed.value : null;
}

export function formatVariantAttributesForForm(
  value: VariantAttributesJson,
): string {
  if (Object.keys(value).length === 0) {
    return "";
  }
  return JSON.stringify(value, null, 2);
}

export function formatVariantAttributesLabel(
  value: VariantAttributesJson,
): string {
  const keys = Object.keys(value);
  if (keys.length === 0) {
    return "None";
  }
  return keys.slice(0, 6).join(", ");
}

function normalizeAttributesRoot(value: unknown): ParsedVariantAttributes {
  if (!isPlainObject(value)) {
    return { ok: false, message: VARIANT_ATTRIBUTES_INVALID_MESSAGE };
  }

  const metrics: AttributeMetrics = { keyCount: 0 };
  const normalized = normalizeAttributeNode(value, 1, metrics);
  if (!normalized.ok) {
    return normalized;
  }
  if (!isPlainObject(normalized.value)) {
    return { ok: false, message: VARIANT_ATTRIBUTES_INVALID_MESSAGE };
  }

  const serialized = JSON.stringify(normalized.value);
  if (serialized.length > VARIANT_ATTR_MAX_SERIALIZED_BYTES) {
    return { ok: false, message: VARIANT_ATTRIBUTES_INVALID_MESSAGE };
  }

  return { ok: true, value: normalized.value };
}

function normalizeAttributeNode(
  value: unknown,
  depth: number,
  metrics: AttributeMetrics,
): { ok: true; value: VariantAttributeValue } | { ok: false; message: string } {
  if (value === null) {
    return { ok: true, value: null };
  }
  if (typeof value === "boolean") {
    return { ok: true, value };
  }
  if (typeof value === "number") {
    if (!Number.isFinite(value)) {
      return { ok: false, message: VARIANT_ATTRIBUTES_INVALID_MESSAGE };
    }
    return { ok: true, value };
  }
  if (typeof value === "string") {
    if (value.length > VARIANT_ATTR_MAX_STRING_VALUE_LENGTH) {
      return { ok: false, message: VARIANT_ATTRIBUTES_INVALID_MESSAGE };
    }
    return { ok: true, value };
  }
  if (Array.isArray(value)) {
    return { ok: false, message: VARIANT_ATTRIBUTES_INVALID_MESSAGE };
  }
  if (!isPlainObject(value)) {
    return { ok: false, message: VARIANT_ATTRIBUTES_INVALID_MESSAGE };
  }
  if (depth > VARIANT_ATTR_MAX_DEPTH) {
    return { ok: false, message: VARIANT_ATTRIBUTES_INVALID_MESSAGE };
  }

  const normalized: VariantAttributeObject = {};
  for (const [key, entryValue] of Object.entries(value)) {
    if (
      key.length === 0 ||
      key.length > VARIANT_ATTR_MAX_KEY_LENGTH ||
      FORBIDDEN_ATTR_KEYS.has(key)
    ) {
      return { ok: false, message: VARIANT_ATTRIBUTES_INVALID_MESSAGE };
    }

    metrics.keyCount += 1;
    if (metrics.keyCount > VARIANT_ATTR_MAX_KEYS) {
      return { ok: false, message: VARIANT_ATTRIBUTES_INVALID_MESSAGE };
    }

    const parsedChild = normalizeAttributeNode(entryValue, depth + 1, metrics);
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
