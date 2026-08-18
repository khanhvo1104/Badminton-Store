import {
  formatVariantAttributesForForm,
  formatVariantAttributesLabel,
  parseVariantAttributesValue,
  type VariantAttributesJson,
} from "@/features/variants/attributes";
import { VARIANT_NO_COST_LABEL } from "@/features/variants/constants";
import {
  formatSellingPrice,
  parseVariantMoney,
} from "@/features/variants/money";
import type { VariantListItem } from "@/features/variants/types";
import { isValidUuid } from "@/features/products/validation";

export type VariantSafeRow = {
  id: string;
  product_id: string;
  sku: string;
  name: string | null;
  color_name: string | null;
  color_hex: string | null;
  racket_weight_class: string | null;
  grip_size: string | null;
  shoe_size: string | null;
  clothing_size: string | null;
  unit: string;
  price: string;
  compare_at_price: string | null;
  attributes: VariantAttributesJson;
  is_default: boolean;
  is_active: boolean;
  sort_order: number;
};

export type VariantCostRow = {
  variant_id: string;
  cost_price: string | null;
};

const PROTECTED_KEYS = ["cost_price", "barcode"] as const;

export function isVariantSafeRow(value: unknown): value is VariantSafeRow {
  return mapVariantSafeRow(value) !== null;
}

export function mapVariantSafeRow(value: unknown): VariantSafeRow | null {
  if (!isRecord(value) || hasProtectedKeys(value)) {
    return null;
  }

  const id = value.id;
  const productId = value.product_id;
  const sku = value.sku;
  const name = value.name;
  const colorName = value.color_name;
  const colorHex = value.color_hex;
  const racketWeightClass = value.racket_weight_class;
  const gripSize = value.grip_size;
  const shoeSize = value.shoe_size;
  const clothingSize = value.clothing_size;
  const unit = value.unit;
  const price = parseVariantMoney(value.price);
  const compareAtPrice =
    value.compare_at_price === null || value.compare_at_price === undefined
      ? null
      : parseVariantMoney(value.compare_at_price);
  const attributes = parseVariantAttributesValue(value.attributes);
  const isDefault = value.is_default;
  const isActive = value.is_active;
  const sortOrder = value.sort_order;

  if (typeof id !== "string" || !isValidUuid(id)) {
    return null;
  }
  if (typeof productId !== "string" || !isValidUuid(productId)) {
    return null;
  }
  if (typeof sku !== "string" || typeof unit !== "string") {
    return null;
  }
  if (price === null) {
    return null;
  }
  if (value.compare_at_price != null && compareAtPrice === null) {
    return null;
  }
  if (attributes === null) {
    return null;
  }
  if (typeof isDefault !== "boolean" || typeof isActive !== "boolean") {
    return null;
  }
  if (typeof sortOrder !== "number" || !Number.isSafeInteger(sortOrder)) {
    return null;
  }
  if (!isOptionalString(name) || !isOptionalString(colorName)) {
    return null;
  }
  if (!isOptionalString(colorHex) || !isOptionalString(racketWeightClass)) {
    return null;
  }
  if (
    !isOptionalString(gripSize) ||
    !isOptionalString(shoeSize) ||
    !isOptionalString(clothingSize)
  ) {
    return null;
  }

  return {
    id,
    product_id: productId,
    sku,
    name,
    color_name: colorName,
    color_hex: colorHex,
    racket_weight_class: racketWeightClass,
    grip_size: gripSize,
    shoe_size: shoeSize,
    clothing_size: clothingSize,
    unit,
    price,
    compare_at_price: compareAtPrice,
    attributes,
    is_default: isDefault,
    is_active: isActive,
    sort_order: sortOrder,
  };
}

export function mapVariantCostRow(value: unknown): VariantCostRow | null {
  if (
    !isRecord(value) ||
    Object.prototype.hasOwnProperty.call(value, "barcode")
  ) {
    return null;
  }

  const variantId = value.variant_id;
  if (typeof variantId !== "string" || !isValidUuid(variantId)) {
    return null;
  }

  if (!Object.prototype.hasOwnProperty.call(value, "cost_price")) {
    return null;
  }

  if (value.cost_price === null) {
    return { variant_id: variantId, cost_price: null };
  }

  const costPrice = parseVariantMoney(value.cost_price);
  if (costPrice === null) {
    return null;
  }

  return { variant_id: variantId, cost_price: costPrice };
}

export function mapVariantListItem(
  row: VariantSafeRow,
  costPrice: string | null,
): VariantListItem {
  return {
    id: row.id,
    productId: row.product_id,
    sku: row.sku,
    name: row.name,
    statusLabel: row.is_active ? "Active" : "Inactive",
    defaultLabel: row.is_default ? "Default" : "Not default",
    isDefault: row.is_default,
    isActive: row.is_active,
    attributesLabel: formatVariantAttributesLabel(row.attributes),
    price: row.price,
    priceLabel: formatSellingPrice(row.price),
    compareAtPrice: row.compare_at_price,
    compareAtPriceLabel: row.compare_at_price
      ? formatSellingPrice(row.compare_at_price)
      : "None",
    costPrice,
    costPriceLabel:
      costPrice === null
        ? VARIANT_NO_COST_LABEL
        : formatSellingPrice(costPrice),
    unit: row.unit,
    sortOrder: row.sort_order,
    colorName: row.color_name,
    colorHex: row.color_hex,
    racketWeightClass: row.racket_weight_class,
    gripSize: row.grip_size,
    shoeSize: row.shoe_size,
    clothingSize: row.clothing_size,
    attributes: row.attributes,
  };
}

export function variantFormValuesFromItem(
  item: VariantListItem,
): import("@/features/variants/types").VariantFormValues {
  return {
    sku: item.sku,
    name: item.name ?? "",
    colorName: item.colorName ?? "",
    colorHex: item.colorHex ?? "",
    racketWeightClass: item.racketWeightClass ?? "",
    gripSize: item.gripSize ?? "",
    shoeSize: item.shoeSize ?? "",
    clothingSize: item.clothingSize ?? "",
    unit: item.unit,
    price: item.price,
    compareAtPrice: item.compareAtPrice ?? "",
    costPrice: item.costPrice ?? "",
    barcode: "",
    barcodeClear: false,
    attributes: formatVariantAttributesForForm(item.attributes),
    isDefault: item.isDefault ? "true" : "false",
    isActive: item.isActive ? "true" : "false",
    sortOrder: String(item.sortOrder),
  };
}

export function readSavedVariantId(data: unknown): string | null {
  if (typeof data === "string" && isValidUuid(data)) {
    return data;
  }

  const row = Array.isArray(data) ? data[0] : data;
  if (!isRecord(row) || hasProtectedKeys(row)) {
    return null;
  }
  if (typeof row.variant_id !== "string" || !isValidUuid(row.variant_id)) {
    return null;
  }
  const keys = Object.keys(row);
  if (keys.length !== 1 || keys[0] !== "variant_id") {
    return null;
  }
  return row.variant_id;
}

function hasProtectedKeys(value: Record<string, unknown>): boolean {
  return PROTECTED_KEYS.some((key) =>
    Object.prototype.hasOwnProperty.call(value, key),
  );
}

function isOptionalString(value: unknown): value is string | null {
  return value === null || typeof value === "string";
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null;
}
