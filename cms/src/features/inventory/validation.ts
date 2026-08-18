import {
  INVENTORY_DEFAULT_SORT,
  INVENTORY_DEFAULT_STOCK,
  INVENTORY_EXACT_INTEGER_PATTERN,
  INVENTORY_LIST_PATH,
  INVENTORY_NOTE_MAX_LENGTH,
  INVENTORY_OPERATIONS,
  INVENTORY_PAGE_SIZE_DEFAULT,
  INVENTORY_PAGE_SIZE_MAX,
  INVENTORY_QUANTITY_MAX,
  INVENTORY_REASONS,
  INVENTORY_SORTS,
  INVENTORY_STOCK_STATES,
} from "@/features/inventory/constants";
import { normalizeInventorySearch } from "@/features/inventory/search";
import type {
  InventoryExplorerQuery,
  InventoryOperation,
  InventoryPagination,
  InventoryReason,
  InventorySort,
  InventoryStockState,
} from "@/features/inventory/types";

type SearchParamsInput =
  | Record<string, string | string[] | undefined>
  | URLSearchParams;

export function parseInventoryPagination(
  searchParams: SearchParamsInput,
): InventoryPagination {
  const pageSize = clampInt(
    parseStrictPositiveInt(readSearchParam(searchParams, "pageSize")),
    1,
    INVENTORY_PAGE_SIZE_MAX,
    INVENTORY_PAGE_SIZE_DEFAULT,
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

export function parseInventoryExplorerQuery(
  searchParams: SearchParamsInput,
): InventoryExplorerQuery {
  const search = normalizeInventorySearch(
    readSearchParam(searchParams, "q") ?? "",
  );
  const stockRaw = (readSearchParam(searchParams, "stock") ?? "").trim();
  const sortRaw = (readSearchParam(searchParams, "sort") ?? "").trim();

  return {
    search,
    stock: isInventoryStockState(stockRaw) ? stockRaw : INVENTORY_DEFAULT_STOCK,
    sort: isInventorySort(sortRaw) ? sortRaw : INVENTORY_DEFAULT_SORT,
    pagination: parseInventoryPagination(searchParams),
  };
}

export function inventoryExplorerHasActiveFilters(
  query: InventoryExplorerQuery,
): boolean {
  return Boolean(
    query.search ||
      query.stock !== INVENTORY_DEFAULT_STOCK ||
      query.sort !== INVENTORY_DEFAULT_SORT,
  );
}

export function getInventoryExplorerRpcArgs(query: InventoryExplorerQuery) {
  return {
    p_search: query.search,
    p_stock: query.stock,
    p_sort: query.sort,
    p_offset: query.pagination.from,
    p_limit: query.pagination.pageSize,
  };
}

export function inventoryExplorerHref(
  query: Pick<InventoryExplorerQuery, "search" | "stock" | "sort"> & {
    pagination?: Pick<InventoryPagination, "page" | "pageSize">;
  },
): string {
  const params = new URLSearchParams();
  const page = query.pagination?.page ?? 1;
  const pageSize = query.pagination?.pageSize;

  if (query.search) {
    params.set("q", query.search);
  }
  if (query.stock !== INVENTORY_DEFAULT_STOCK) {
    params.set("stock", query.stock);
  }
  if (query.sort !== INVENTORY_DEFAULT_SORT) {
    params.set("sort", query.sort);
  }
  if (pageSize && pageSize !== INVENTORY_PAGE_SIZE_DEFAULT) {
    params.set("pageSize", String(pageSize));
  }
  if (page > 1) {
    params.set("page", String(page));
  }

  const encoded = params.toString();
  return encoded ? `${INVENTORY_LIST_PATH}?${encoded}` : INVENTORY_LIST_PATH;
}

export function parseExactInteger(raw: string): number | null {
  const trimmed = raw.trim();
  if (!INVENTORY_EXACT_INTEGER_PATTERN.test(trimmed)) {
    return null;
  }
  const value = Number(trimmed);
  if (!Number.isInteger(value) || value > INVENTORY_QUANTITY_MAX) {
    return null;
  }
  return value;
}

export function isInventoryOperation(
  value: string,
): value is InventoryOperation {
  return (INVENTORY_OPERATIONS as readonly string[]).includes(value);
}

export function isInventoryReason(value: string): value is InventoryReason {
  return (INVENTORY_REASONS as readonly string[]).includes(value);
}

export function normalizeInventoryReason(raw: string): string {
  return raw.trim().toLowerCase().replace(/\s+/g, "_");
}

export function normalizeInventoryNote(raw: string): string | null {
  const collapsed = raw.trim().replace(/\s+/g, " ");
  if (!collapsed) {
    return null;
  }
  return collapsed.slice(0, INVENTORY_NOTE_MAX_LENGTH);
}

function isInventoryStockState(value: string): value is InventoryStockState {
  return (INVENTORY_STOCK_STATES as readonly string[]).includes(value);
}

function isInventorySort(value: string): value is InventorySort {
  return (INVENTORY_SORTS as readonly string[]).includes(value);
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
