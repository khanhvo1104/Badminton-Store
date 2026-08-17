import { PRODUCT_STATUS_LABELS } from "@/features/products/constants";
import { buildProductImagePublicUrl } from "@/features/products/image";
import {
  aggregateInventory,
  type InventoryAggregateInput,
} from "@/features/products/inventory";
import {
  compareSellingPrices,
  formatPriceRange,
  parseSellingPrice,
  sellingPriceToCents,
} from "@/features/products/money";
import type {
  ProductListItem,
  ProductSort,
  ProductStatus,
} from "@/features/products/types";
import { isValidUuid } from "@/features/products/validation";

export type ProductRow = {
  id: string;
  category_id: string;
  brand_id: string | null;
  name: string;
  slug: string;
  status: ProductStatus;
  is_featured: boolean;
  published_at: string | null;
  updated_at: string;
};

export type ProductVariantRow = {
  id: string;
  product_id: string;
  price: string;
  is_active: boolean;
};

export type ProductInventoryRow = {
  variant_id: string;
  quantity_on_hand: number;
  quantity_reserved: number;
  reorder_level: number;
};

export type ProductImageRow = {
  product_id: string;
  storage_path: string;
  variant_id: string | null;
  is_primary: boolean;
};

export type ProductNameRow = {
  id: string;
  name: string;
};

export type ProductFilterOptionRow = {
  id: string;
  name: string;
  is_active: boolean;
};

const PRODUCT_STATUS_SET = new Set<string>([
  "draft",
  "active",
  "inactive",
  "archived",
]);

export function mapProductRow(value: unknown): ProductRow | null {
  if (!isRecord(value)) {
    return null;
  }

  const id = value.id;
  const categoryId = value.category_id;
  const brandId = value.brand_id;
  const name = value.name;
  const slug = value.slug;
  const status = value.status;
  const isFeatured = value.is_featured;
  const publishedAt = value.published_at;
  const updatedAt = value.updated_at;

  if (typeof id !== "string" || !isValidUuid(id)) {
    return null;
  }
  if (typeof categoryId !== "string" || !isValidUuid(categoryId)) {
    return null;
  }
  if (brandId !== null && typeof brandId !== "string") {
    return null;
  }
  if (typeof brandId === "string" && !isValidUuid(brandId)) {
    return null;
  }
  if (typeof name !== "string" || typeof slug !== "string") {
    return null;
  }
  if (typeof status !== "string" || !PRODUCT_STATUS_SET.has(status)) {
    return null;
  }
  if (typeof isFeatured !== "boolean") {
    return null;
  }
  if (publishedAt !== null && typeof publishedAt !== "string") {
    return null;
  }
  if (typeof updatedAt !== "string" || !isParsableDate(updatedAt)) {
    return null;
  }
  if (publishedAt !== null && !isParsableDate(publishedAt)) {
    return null;
  }

  return {
    id,
    category_id: categoryId,
    brand_id: brandId,
    name,
    slug,
    status: status as ProductStatus,
    is_featured: isFeatured,
    published_at: publishedAt,
    updated_at: updatedAt,
  };
}

export function mapProductVariantRow(value: unknown): ProductVariantRow | null {
  if (!isRecord(value)) {
    return null;
  }

  const id = value.id;
  const productId = value.product_id;
  const price = parseSellingPrice(value.price);
  const isActive = value.is_active;

  if (typeof id !== "string" || !isValidUuid(id)) {
    return null;
  }
  if (typeof productId !== "string" || !isValidUuid(productId)) {
    return null;
  }
  if (price === null) {
    return null;
  }
  if (typeof isActive !== "boolean") {
    return null;
  }

  return {
    id,
    product_id: productId,
    price,
    is_active: isActive,
  };
}

export function mapProductInventoryRow(
  value: unknown,
): ProductInventoryRow | null {
  if (!isRecord(value)) {
    return null;
  }

  const variantId = value.variant_id;
  const quantityOnHand = parseNonNegativeInt(value.quantity_on_hand);
  const quantityReserved = parseNonNegativeInt(value.quantity_reserved);
  const reorderLevel = parseNonNegativeInt(value.reorder_level);

  if (typeof variantId !== "string" || !isValidUuid(variantId)) {
    return null;
  }
  if (
    quantityOnHand === null ||
    quantityReserved === null ||
    reorderLevel === null
  ) {
    return null;
  }

  return {
    variant_id: variantId,
    quantity_on_hand: quantityOnHand,
    quantity_reserved: quantityReserved,
    reorder_level: reorderLevel,
  };
}

export function mapProductImageRow(value: unknown): ProductImageRow | null {
  if (!isRecord(value)) {
    return null;
  }

  const productId = value.product_id;
  const storagePath = value.storage_path;
  const variantId = value.variant_id;
  const isPrimary = value.is_primary;

  if (typeof productId !== "string" || !isValidUuid(productId)) {
    return null;
  }
  if (typeof storagePath !== "string" || !storagePath.trim()) {
    return null;
  }
  if (variantId !== null && typeof variantId !== "string") {
    return null;
  }
  if (typeof variantId === "string" && !isValidUuid(variantId)) {
    return null;
  }
  if (typeof isPrimary !== "boolean") {
    return null;
  }

  return {
    product_id: productId,
    storage_path: storagePath,
    variant_id: variantId,
    is_primary: isPrimary,
  };
}

export function mapProductNameRow(value: unknown): ProductNameRow | null {
  if (!isRecord(value)) {
    return null;
  }

  const id = value.id;
  const name = value.name;
  if (typeof id !== "string" || !isValidUuid(id) || typeof name !== "string") {
    return null;
  }

  return { id, name };
}

export function mapProductFilterOptionRow(
  value: unknown,
): ProductFilterOptionRow | null {
  if (!isRecord(value)) {
    return null;
  }

  const id = value.id;
  const name = value.name;
  const isActive = value.is_active;
  if (
    typeof id !== "string" ||
    !isValidUuid(id) ||
    typeof name !== "string" ||
    typeof isActive !== "boolean"
  ) {
    return null;
  }

  return { id, name, is_active: isActive };
}

export function isProductRow(value: unknown): value is ProductRow {
  return mapProductRow(value) !== null;
}

export function mapProductListItem(options: {
  row: ProductRow;
  categoryName: string | null;
  brandName: string | null;
  variants: ProductVariantRow[];
  inventoryByVariantId: Map<string, ProductInventoryRow>;
  primaryImagePath: string | null;
  supabaseUrl: string;
}): ProductListItem | null {
  const {
    row,
    categoryName,
    brandName,
    variants,
    inventoryByVariantId,
    primaryImagePath,
    supabaseUrl,
  } = options;

  const inventoryRows: InventoryAggregateInput["rows"] = [];
  for (const variant of variants) {
    const inventory = inventoryByVariantId.get(variant.id);
    if (!inventory) {
      continue;
    }
    inventoryRows.push({
      quantityOnHand: inventory.quantity_on_hand,
      quantityReserved: inventory.quantity_reserved,
      reorderLevel: inventory.reorder_level,
    });
  }

  const inventory = aggregateInventory({
    variantCount: variants.length,
    rows: inventoryRows,
  });
  if (!inventory) {
    return null;
  }

  let minAmount: string | null = null;
  let maxAmount: string | null = null;
  for (const variant of variants) {
    if (
      minAmount === null ||
      compareSellingPrices(variant.price, minAmount) < 0
    ) {
      minAmount = variant.price;
    }
    if (
      maxAmount === null ||
      compareSellingPrices(variant.price, maxAmount) > 0
    ) {
      maxAmount = variant.price;
    }
  }

  return {
    id: row.id,
    name: row.name,
    slug: row.slug,
    categoryId: row.category_id,
    categoryName,
    brandId: row.brand_id,
    brandName,
    status: row.status,
    statusLabel: PRODUCT_STATUS_LABELS[row.status],
    isFeatured: row.is_featured,
    featuredLabel: row.is_featured ? "Featured" : "Not featured",
    publishedAt: row.published_at,
    publishedAtLabel: formatTimestamp(row.published_at),
    updatedAt: row.updated_at,
    updatedAtLabel: formatTimestamp(row.updated_at),
    primaryImageUrl: buildProductImagePublicUrl(supabaseUrl, primaryImagePath),
    activeVariantCount: variants.filter((variant) => variant.is_active).length,
    totalVariantCount: variants.length,
    priceRange: {
      minAmount,
      maxAmount,
      label: formatPriceRange(minAmount, maxAmount),
    },
    inventory,
  };
}

export function compareProductListItems(
  left: ProductListItem,
  right: ProductListItem,
  sort: ProductSort,
): number {
  if (sort === "price_asc" || sort === "price_desc") {
    const leftCents = priceSortKey(left);
    const rightCents = priceSortKey(right);
    if (leftCents === null && rightCents === null) {
      return left.id.localeCompare(right.id);
    }
    if (leftCents === null) {
      return 1;
    }
    if (rightCents === null) {
      return -1;
    }
    if (leftCents !== rightCents) {
      const delta = leftCents < rightCents ? -1 : 1;
      return sort === "price_asc" ? delta : -delta;
    }
    return left.id.localeCompare(right.id);
  }

  return left.id.localeCompare(right.id);
}

function priceSortKey(item: ProductListItem): bigint | null {
  if (item.priceRange.minAmount === null) {
    return null;
  }
  return sellingPriceToCents(item.priceRange.minAmount);
}

function formatTimestamp(value: string | null): string {
  if (!value) {
    return "Not published";
  }

  return new Intl.DateTimeFormat("en-GB", {
    dateStyle: "medium",
    timeStyle: "short",
    timeZone: "UTC",
  }).format(new Date(value));
}

function parseNonNegativeInt(value: unknown): number | null {
  if (typeof value !== "number" || !Number.isSafeInteger(value) || value < 0) {
    return null;
  }
  return value;
}

function isParsableDate(value: string): boolean {
  return !Number.isNaN(Date.parse(value));
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null;
}
