import {
  PRODUCT_NO_INVENTORY_LABEL,
  PRODUCT_STATUS_LABELS,
  PRODUCT_STOCK_LABELS,
} from "@/features/products/constants";
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
  ProductInventorySummary,
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

export type CmsProductRpcRow = {
  id: string | null;
  category_id: string | null;
  brand_id: string | null;
  name: string | null;
  slug: string | null;
  status: ProductStatus | null;
  is_featured: boolean | null;
  published_at: string | null;
  updated_at: string | null;
  active_variant_count: number | null;
  total_variant_count: number | null;
  min_price: string | null;
  max_price: string | null;
  total_on_hand: number | null;
  total_reserved: number | null;
  total_available: number | null;
  missing_inventory_count: number;
  has_missing_inventory: boolean;
  is_low_stock: boolean;
  stock_state: Exclude<ProductInventorySummary["stockState"], never>;
  filtered_count: number;
};

export function mapCmsProductRpcRow(value: unknown): CmsProductRpcRow | null {
  if (!isRecord(value)) {
    return null;
  }

  const filteredCount = parseNonNegativeInt(value.filtered_count);
  if (filteredCount === null) {
    return null;
  }

  const id = value.id;
  if (id === null) {
    return {
      id: null,
      category_id: null,
      brand_id: null,
      name: null,
      slug: null,
      status: null,
      is_featured: null,
      published_at: null,
      updated_at: null,
      active_variant_count: null,
      total_variant_count: null,
      min_price: null,
      max_price: null,
      total_on_hand: null,
      total_reserved: null,
      total_available: null,
      missing_inventory_count: 0,
      has_missing_inventory: false,
      is_low_stock: false,
      stock_state: "out_of_stock",
      filtered_count: filteredCount,
    };
  }

  const product = mapProductRow({
    id: value.id,
    category_id: value.category_id,
    brand_id: value.brand_id,
    name: value.name,
    slug: value.slug,
    status: value.status,
    is_featured: value.is_featured,
    published_at: value.published_at,
    updated_at: value.updated_at,
  });
  if (!product) {
    return null;
  }

  const activeVariantCount = parseNonNegativeInt(value.active_variant_count);
  const totalVariantCount = parseNonNegativeInt(value.total_variant_count);
  const missingInventoryCount = parseNonNegativeInt(
    value.missing_inventory_count,
  );
  if (
    activeVariantCount === null ||
    totalVariantCount === null ||
    missingInventoryCount === null ||
    activeVariantCount > totalVariantCount
  ) {
    return null;
  }

  const minPrice =
    value.min_price === null || value.min_price === undefined
      ? null
      : parseSellingPrice(value.min_price);
  const maxPrice =
    value.max_price === null || value.max_price === undefined
      ? null
      : parseSellingPrice(value.max_price);
  if (value.min_price != null && minPrice === null) {
    return null;
  }
  if (value.max_price != null && maxPrice === null) {
    return null;
  }
  if ((minPrice === null) !== (maxPrice === null)) {
    return null;
  }

  if (typeof value.has_missing_inventory !== "boolean") {
    return null;
  }
  if (typeof value.is_low_stock !== "boolean") {
    return null;
  }
  const stockState = value.stock_state;
  if (
    typeof stockState !== "string" ||
    !["in_stock", "low_stock", "out_of_stock", "missing"].includes(stockState)
  ) {
    return null;
  }

  const totalOnHand = parseNullableNonNegativeInt(value.total_on_hand);
  const totalReserved = parseNullableNonNegativeInt(value.total_reserved);
  const totalAvailable = parseNullableNonNegativeInt(value.total_available);
  if (
    totalOnHand === undefined ||
    totalReserved === undefined ||
    totalAvailable === undefined
  ) {
    return null;
  }

  return {
    id: product.id,
    category_id: product.category_id,
    brand_id: product.brand_id,
    name: product.name,
    slug: product.slug,
    status: product.status,
    is_featured: product.is_featured,
    published_at: product.published_at,
    updated_at: product.updated_at,
    active_variant_count: activeVariantCount,
    total_variant_count: totalVariantCount,
    min_price: minPrice,
    max_price: maxPrice,
    total_on_hand: totalOnHand,
    total_reserved: totalReserved,
    total_available: totalAvailable,
    missing_inventory_count: missingInventoryCount,
    has_missing_inventory: value.has_missing_inventory,
    is_low_stock: value.is_low_stock,
    stock_state: stockState as CmsProductRpcRow["stock_state"],
    filtered_count: filteredCount,
  };
}

export function inventorySummaryFromRpc(
  row: CmsProductRpcRow,
): ProductInventorySummary | null {
  if (row.id === null) {
    return null;
  }

  const stockLabel = row.has_missing_inventory
    ? PRODUCT_NO_INVENTORY_LABEL
    : PRODUCT_STOCK_LABELS[row.stock_state];

  return {
    totalOnHand: row.total_on_hand,
    totalReserved: row.total_reserved,
    totalAvailable: row.total_available,
    missingInventoryCount: row.missing_inventory_count,
    hasMissingInventory: row.has_missing_inventory,
    isLowStock: row.is_low_stock,
    stockState: row.stock_state,
    stockLabel,
  };
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

function parseNullableNonNegativeInt(
  value: unknown,
): number | null | undefined {
  if (value === null) {
    return null;
  }
  const parsed = parseNonNegativeInt(value);
  return parsed === null ? undefined : parsed;
}

function isParsableDate(value: string): boolean {
  return !Number.isNaN(Date.parse(value));
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null;
}
