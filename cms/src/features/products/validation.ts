import {
  PRODUCT_DEFAULT_SORT,
  PRODUCT_DEFAULT_STOCK,
  PRODUCT_LIST_ORDER,
  PRODUCT_PAGE_SIZE_DEFAULT,
  PRODUCT_PAGE_SIZE_MAX,
  PRODUCT_SORTS,
  PRODUCT_STATUSES,
  PRODUCT_STOCK_STATES,
  PRODUCTS_LIST_PATH,
  UUID_PATTERN,
} from "@/features/products/constants";
import { normalizeProductSearch } from "@/features/products/search";
import type {
  ProductExplorerQuery,
  ProductPagination,
  ProductSort,
  ProductStatus,
  ProductStockState,
} from "@/features/products/types";

type SearchParamsInput =
  | Record<string, string | string[] | undefined>
  | URLSearchParams;

export function isValidUuid(value: string): boolean {
  return UUID_PATTERN.test(value);
}

export function parseProductPagination(
  searchParams: SearchParamsInput,
): ProductPagination {
  const pageSize = clampInt(
    parseStrictPositiveInt(readSearchParam(searchParams, "pageSize")),
    1,
    PRODUCT_PAGE_SIZE_MAX,
    PRODUCT_PAGE_SIZE_DEFAULT,
  );
  const page = clampInt(
    parseStrictPositiveInt(readSearchParam(searchParams, "page")),
    1,
    1_000_000,
    1,
  );
  const from = (page - 1) * pageSize;
  const to = from + pageSize - 1;

  return { page, pageSize, from, to };
}

export function parseProductExplorerQuery(
  searchParams: SearchParamsInput,
): ProductExplorerQuery {
  const search = normalizeProductSearch(
    readSearchParam(searchParams, "q") ?? "",
  );
  const categoryRaw = (readSearchParam(searchParams, "category") ?? "").trim();
  const brandRaw = (readSearchParam(searchParams, "brand") ?? "").trim();
  const statusRaw = (readSearchParam(searchParams, "status") ?? "").trim();
  const stockRaw = (readSearchParam(searchParams, "stock") ?? "").trim();
  const sortRaw = (readSearchParam(searchParams, "sort") ?? "").trim();

  return {
    search,
    categoryId: isValidUuid(categoryRaw) ? categoryRaw : null,
    brandId: isValidUuid(brandRaw) ? brandRaw : null,
    status: isProductStatus(statusRaw) ? statusRaw : null,
    stock: isProductStockState(stockRaw) ? stockRaw : PRODUCT_DEFAULT_STOCK,
    sort: isProductSort(sortRaw) ? sortRaw : PRODUCT_DEFAULT_SORT,
    pagination: parseProductPagination(searchParams),
  };
}

export function productExplorerHasActiveFilters(
  query: ProductExplorerQuery,
): boolean {
  return Boolean(
    query.search ||
      query.categoryId ||
      query.brandId ||
      query.status ||
      query.stock !== PRODUCT_DEFAULT_STOCK ||
      query.sort !== PRODUCT_DEFAULT_SORT,
  );
}

export function getProductListOrder(sort: ProductSort) {
  return PRODUCT_LIST_ORDER[sort];
}

export function getProductExplorerRpcArgs(query: ProductExplorerQuery) {
  return {
    p_search: query.search,
    p_category_id: query.categoryId,
    p_brand_id: query.brandId,
    p_status: query.status,
    p_stock: query.stock,
    p_sort: query.sort,
    p_offset: query.pagination.from,
    p_limit: query.pagination.pageSize,
  };
}

export function productExplorerHref(
  query: Pick<
    ProductExplorerQuery,
    "search" | "categoryId" | "brandId" | "status" | "stock" | "sort"
  > & {
    pagination?: Pick<ProductPagination, "page" | "pageSize">;
  },
): string {
  const params = new URLSearchParams();
  const page = query.pagination?.page ?? 1;
  const pageSize = query.pagination?.pageSize;

  if (query.search) {
    params.set("q", query.search);
  }
  if (query.categoryId) {
    params.set("category", query.categoryId);
  }
  if (query.brandId) {
    params.set("brand", query.brandId);
  }
  if (query.status) {
    params.set("status", query.status);
  }
  if (query.stock !== PRODUCT_DEFAULT_STOCK) {
    params.set("stock", query.stock);
  }
  if (query.sort !== PRODUCT_DEFAULT_SORT) {
    params.set("sort", query.sort);
  }
  if (pageSize && pageSize !== PRODUCT_PAGE_SIZE_DEFAULT) {
    params.set("pageSize", String(pageSize));
  }
  if (page > 1) {
    params.set("page", String(page));
  }

  const encoded = params.toString();
  return encoded ? `${PRODUCTS_LIST_PATH}?${encoded}` : PRODUCTS_LIST_PATH;
}

function isProductStatus(value: string): value is ProductStatus {
  return (PRODUCT_STATUSES as readonly string[]).includes(value);
}

function isProductStockState(value: string): value is ProductStockState {
  return (PRODUCT_STOCK_STATES as readonly string[]).includes(value);
}

function isProductSort(value: string): value is ProductSort {
  return (PRODUCT_SORTS as readonly string[]).includes(value);
}

function readSearchParam(
  searchParams: SearchParamsInput,
  key: string,
): string | undefined {
  if (searchParams instanceof URLSearchParams) {
    return searchParams.get(key) ?? undefined;
  }

  const value = searchParams[key];
  if (Array.isArray(value)) {
    return value[0];
  }
  return value;
}

function parseStrictPositiveInt(raw: string | undefined): number | null {
  if (raw === undefined) {
    return null;
  }
  const trimmed = raw.trim();
  if (!/^[1-9]\d*$/.test(trimmed)) {
    return null;
  }
  const value = Number(trimmed);
  return Number.isSafeInteger(value) ? value : null;
}

function clampInt(
  value: number | null,
  min: number,
  max: number,
  fallback: number,
): number {
  if (value === null) {
    return fallback;
  }
  return Math.min(max, Math.max(min, value));
}
