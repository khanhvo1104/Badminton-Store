import {
  STAFF_LIST_PATH,
  STAFF_PAGE_SIZE_DEFAULT,
  STAFF_PAGE_SIZE_MAX,
  STAFF_ROLE_FILTERS,
  STAFF_ACTIVE_FILTERS,
  STAFF_SORTS,
} from "@/features/staff/constants";
import { normalizeStaffSearch } from "@/features/staff/search";
import type {
  StaffActiveFilter,
  StaffExplorerQuery,
  StaffRoleFilter,
  StaffSort,
} from "@/features/staff/types";

type SearchParamsInput =
  | Record<string, string | string[] | undefined>
  | URLSearchParams;

export type StaffPagination = {
  page: number;
  pageSize: number;
  offset: number;
};

export function parseStaffPagination(
  searchParams: SearchParamsInput,
): StaffPagination {
  const pageSize = clampInt(
    parseStrictPositiveInt(readSearchParam(searchParams, "pageSize")),
    1,
    STAFF_PAGE_SIZE_MAX,
    STAFF_PAGE_SIZE_DEFAULT,
  );
  const page = clampInt(
    parseStrictPositiveInt(readSearchParam(searchParams, "page")),
    1,
    1_000_000,
    1,
  );

  return {
    page,
    pageSize,
    offset: (page - 1) * pageSize,
  };
}

export function parseStaffExplorerQuery(
  searchParams: SearchParamsInput,
): StaffExplorerQuery {
  const search = normalizeStaffSearch(readSearchParam(searchParams, "q") ?? "");
  const role = parseRoleFilter(readSearchParam(searchParams, "role"));
  const active = parseActiveFilter(readSearchParam(searchParams, "active"));
  const sort = parseSort(readSearchParam(searchParams, "sort"));

  return {
    search,
    role,
    active,
    sort,
    pagination: parseStaffPagination(searchParams),
  };
}

export function staffExplorerHasActiveFilters(
  query: StaffExplorerQuery,
): boolean {
  return (
    query.search.length > 0 ||
    query.role !== "all" ||
    query.active !== "all" ||
    query.sort !== "name_asc"
  );
}

export function staffExplorerHref(query: StaffExplorerQuery): string {
  const params = new URLSearchParams();

  if (query.search) {
    params.set("q", query.search);
  }
  if (query.role !== "all") {
    params.set("role", query.role);
  }
  if (query.active !== "all") {
    params.set("active", query.active);
  }
  if (query.sort !== "name_asc") {
    params.set("sort", query.sort);
  }
  if (query.pagination.page !== 1) {
    params.set("page", String(query.pagination.page));
  }
  if (query.pagination.pageSize !== STAFF_PAGE_SIZE_DEFAULT) {
    params.set("pageSize", String(query.pagination.pageSize));
  }

  const queryString = params.toString();
  return queryString ? `${STAFF_LIST_PATH}?${queryString}` : STAFF_LIST_PATH;
}

export function getStaffExplorerRpcArgs(query: StaffExplorerQuery) {
  return {
    p_search: query.search,
    p_role: query.role,
    p_active: query.active,
    p_sort: query.sort,
    p_offset: query.pagination.offset,
    p_limit: query.pagination.pageSize,
  };
}

function parseRoleFilter(value: string | undefined): StaffRoleFilter {
  const normalized = (value ?? "").trim();
  return STAFF_ROLE_FILTERS.includes(normalized as StaffRoleFilter)
    ? (normalized as StaffRoleFilter)
    : "all";
}

function parseActiveFilter(value: string | undefined): StaffActiveFilter {
  const normalized = (value ?? "").trim();
  return STAFF_ACTIVE_FILTERS.includes(normalized as StaffActiveFilter)
    ? (normalized as StaffActiveFilter)
    : "all";
}

function parseSort(value: string | undefined): StaffSort {
  const normalized = (value ?? "").trim();
  return STAFF_SORTS.includes(normalized as StaffSort)
    ? (normalized as StaffSort)
    : "name_asc";
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

function parseStrictPositiveInt(value: string | undefined): number | null {
  if (!value) {
    return null;
  }
  if (!/^\d+$/.test(value)) {
    return null;
  }
  const parsed = Number.parseInt(value, 10);
  return Number.isFinite(parsed) && parsed > 0 ? parsed : null;
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
