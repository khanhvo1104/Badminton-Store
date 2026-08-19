import { buildProductImagePublicUrl } from "@/features/media/image";
import type {
  ProductMediaImage,
  ProductMediaVariantOption,
} from "@/features/media/types";
import { isValidUuid } from "@/features/products/validation";

const PRIMARY_RESULT_KEYS = ["image_id"] as const;
const REORDER_RESULT_KEYS = ["product_id"] as const;

export type ProductImageRow = {
  id: string;
  product_id: string;
  variant_id: string | null;
  storage_path: string;
  alt_text: string | null;
  sort_order: number;
  is_primary: boolean;
  updated_at: string;
};

export type ProductMediaVariantRow = {
  id: string;
  sku: string;
  name: string | null;
};

export function mapProductImageRow(value: unknown): ProductImageRow | null {
  if (!isRecord(value)) {
    return null;
  }

  const id = value.id;
  const productId = value.product_id;
  const variantId = value.variant_id;
  const storagePath = value.storage_path;
  const altText = value.alt_text;
  const sortOrder = value.sort_order;
  const isPrimary = value.is_primary;
  const updatedAt = value.updated_at;

  if (typeof id !== "string" || !isValidUuid(id)) {
    return null;
  }
  if (typeof productId !== "string" || !isValidUuid(productId)) {
    return null;
  }
  if (variantId !== null && typeof variantId !== "string") {
    return null;
  }
  if (typeof variantId === "string" && !isValidUuid(variantId)) {
    return null;
  }
  if (typeof storagePath !== "string" || storagePath.trim() === "") {
    return null;
  }
  if (altText !== null && typeof altText !== "string") {
    return null;
  }
  if (typeof sortOrder !== "number" || !Number.isInteger(sortOrder)) {
    return null;
  }
  if (typeof isPrimary !== "boolean") {
    return null;
  }
  if (typeof updatedAt !== "string" || Number.isNaN(Date.parse(updatedAt))) {
    return null;
  }

  const extraKeys = Object.keys(value).filter(
    (key) =>
      ![
        "id",
        "product_id",
        "variant_id",
        "storage_path",
        "alt_text",
        "sort_order",
        "is_primary",
        "updated_at",
      ].includes(key),
  );
  if (extraKeys.length > 0) {
    return null;
  }

  return {
    id,
    product_id: productId,
    variant_id: variantId,
    storage_path: storagePath,
    alt_text: altText,
    sort_order: sortOrder,
    is_primary: isPrimary,
    updated_at: updatedAt,
  };
}

export function mapProductMediaVariantRow(
  value: unknown,
): ProductMediaVariantRow | null {
  if (!isRecord(value)) {
    return null;
  }
  const id = value.id;
  const sku = value.sku;
  const name = value.name;
  if (typeof id !== "string" || !isValidUuid(id)) {
    return null;
  }
  if (typeof sku !== "string" || sku.trim() === "") {
    return null;
  }
  if (name !== null && typeof name !== "string") {
    return null;
  }
  if (Object.keys(value).some((key) => !["id", "sku", "name"].includes(key))) {
    return null;
  }
  return { id, sku, name };
}

export function toProductMediaVariantOption(
  row: ProductMediaVariantRow,
): ProductMediaVariantOption {
  const name = row.name?.trim() || null;
  return {
    id: row.id,
    sku: row.sku,
    name,
    label: name ? `${row.sku} — ${name}` : row.sku,
  };
}

export function toProductMediaImage(options: {
  row: ProductImageRow;
  supabaseUrl: string;
  variantLabelById: Map<string, string>;
}): ProductMediaImage {
  const { row, supabaseUrl, variantLabelById } = options;
  const variantLabel =
    row.variant_id === null
      ? null
      : (variantLabelById.get(row.variant_id) ?? "Unknown variant");

  return {
    id: row.id,
    productId: row.product_id,
    variantId: row.variant_id,
    variantLabel,
    storagePath: row.storage_path,
    previewUrl: buildProductImagePublicUrl(
      supabaseUrl,
      row.product_id,
      row.storage_path,
    ),
    altText: row.alt_text,
    sortOrder: row.sort_order,
    isPrimary: row.is_primary,
    scopeLabel: variantLabel ? `Variant ${variantLabel}` : "Product gallery",
    primaryLabel: row.is_primary ? "Primary" : "Gallery",
    updatedAt: row.updated_at,
  };
}

export function readPrimaryImageId(
  data: unknown,
  expectedImageId: string,
): string | null {
  if (!isValidUuid(expectedImageId)) {
    return null;
  }
  if (!Array.isArray(data) || data.length !== 1) {
    return null;
  }
  const row = data[0];
  if (!isRecord(row)) {
    return null;
  }
  const keys = Object.keys(row);
  if (
    keys.length !== PRIMARY_RESULT_KEYS.length ||
    keys[0] !== "image_id" ||
    !Object.prototype.hasOwnProperty.call(row, "image_id")
  ) {
    return null;
  }
  if (typeof row.image_id !== "string" || !isValidUuid(row.image_id)) {
    return null;
  }
  if (row.image_id !== expectedImageId) {
    return null;
  }
  return row.image_id;
}

export function readReorderedProductId(
  data: unknown,
  expectedProductId: string,
): string | null {
  if (!isValidUuid(expectedProductId)) {
    return null;
  }
  if (!Array.isArray(data) || data.length !== 1) {
    return null;
  }
  const row = data[0];
  if (!isRecord(row)) {
    return null;
  }
  const keys = Object.keys(row);
  if (
    keys.length !== REORDER_RESULT_KEYS.length ||
    keys[0] !== "product_id" ||
    !Object.prototype.hasOwnProperty.call(row, "product_id")
  ) {
    return null;
  }
  if (typeof row.product_id !== "string" || !isValidUuid(row.product_id)) {
    return null;
  }
  if (row.product_id !== expectedProductId) {
    return null;
  }
  return row.product_id;
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null;
}
