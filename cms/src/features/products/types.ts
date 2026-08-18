import type {
  PRODUCT_SORTS,
  PRODUCT_STATUSES,
  PRODUCT_STOCK_STATES,
} from "@/features/products/constants";
import type { SpecificationsJson } from "@/features/products/specifications";

export type ProductStatus = (typeof PRODUCT_STATUSES)[number];
export type ProductStockState = (typeof PRODUCT_STOCK_STATES)[number];
export type ProductSort = (typeof PRODUCT_SORTS)[number];

export type ProductPagination = {
  page: number;
  pageSize: number;
  from: number;
  to: number;
};

export type ProductExplorerQuery = {
  search: string;
  categoryId: string | null;
  brandId: string | null;
  status: ProductStatus | null;
  stock: ProductStockState;
  sort: ProductSort;
  pagination: ProductPagination;
};

export type ProductFilterOption = {
  id: string;
  name: string;
  isActive: boolean;
};

export type ProductPriceRange = {
  minAmount: string | null;
  maxAmount: string | null;
  label: string;
};

export type ProductInventorySummary = {
  totalOnHand: number | null;
  totalReserved: number | null;
  totalAvailable: number | null;
  missingInventoryCount: number;
  hasMissingInventory: boolean;
  isLowStock: boolean;
  stockState: Exclude<ProductStockState, "all">;
  stockLabel: string;
};

export type ProductListItem = {
  id: string;
  name: string;
  slug: string;
  categoryId: string;
  categoryName: string | null;
  brandId: string | null;
  brandName: string | null;
  status: ProductStatus;
  statusLabel: string;
  isFeatured: boolean;
  featuredLabel: string;
  publishedAt: string | null;
  publishedAtLabel: string;
  updatedAt: string;
  updatedAtLabel: string;
  primaryImageUrl: string | null;
  activeVariantCount: number;
  totalVariantCount: number;
  priceRange: ProductPriceRange;
  inventory: ProductInventorySummary;
};

export type ProductListResult = {
  items: ProductListItem[];
  totalCount: number;
  pagination: ProductPagination;
  totalPages: number;
  query: ProductExplorerQuery;
  hasActiveFilters: boolean;
};

export type ProductExplorerLoadResult =
  | { ok: true; result: ProductListResult }
  | { ok: false; message: string };

export type ProductFormReferenceOption = {
  id: string;
  name: string;
  isActive: boolean;
};

export type ProductDetail = {
  id: string;
  categoryId: string;
  categoryName: string | null;
  brandId: string | null;
  brandName: string | null;
  name: string;
  slug: string;
  shortDescription: string | null;
  description: string | null;
  specifications: SpecificationsJson;
  searchKeywords: string | null;
  status: ProductStatus;
  statusLabel: string;
  isFeatured: boolean;
  featuredLabel: string;
  publishedAt: string | null;
  publishedAtLabel: string;
  updatedAt: string;
  updatedAtLabel: string;
};

export type ProductFormValues = {
  categoryId: string;
  brandId: string;
  name: string;
  slug: string;
  slugManual: boolean;
  shortDescription: string;
  description: string;
  specifications: string;
  searchKeywords: string;
  status: ProductStatus;
  isFeatured: boolean;
  publishedAt: string;
};

export type ProductFieldErrors = {
  categoryId?: string;
  brandId?: string;
  name?: string;
  slug?: string;
  shortDescription?: string;
  description?: string;
  specifications?: string;
  searchKeywords?: string;
  status?: string;
  isFeatured?: string;
  publishedAt?: string;
  form?: string;
};

export type ProductFormState = {
  status: "idle" | "error" | "success";
  message: string | null;
  fieldErrors: ProductFieldErrors;
  values: ProductFormValues;
};

export type ParsedProductInput = {
  categoryId: string;
  brandId: string | null;
  name: string;
  slug: string;
  shortDescription: string | null;
  description: string | null;
  specifications: SpecificationsJson;
  searchKeywords: string | null;
  status: ProductStatus;
  isFeatured: boolean;
  publishedAt: string | null;
};

export type ProductMutationPayload = {
  category_id: string;
  brand_id: string | null;
  name: string;
  slug: string;
  short_description: string | null;
  description: string | null;
  specifications: SpecificationsJson;
  search_keywords: string | null;
  status: ProductStatus;
  is_featured: boolean;
  published_at: string | null;
};
