import {
  ORDERS_DEFAULT_PAYMENT_STATUS,
  ORDERS_DEFAULT_SORT,
  ORDERS_DEFAULT_STATUS,
  ORDERS_LIST_PATH,
  ORDERS_NOTE_MAX_LENGTH,
  ORDERS_PAGE_SIZE_DEFAULT,
  ORDERS_PAGE_SIZE_MAX,
  ORDER_SORTS,
  ORDER_STATUSES,
  ORDER_STATUS_FILTERS,
  ORDER_TRANSITIONS,
  PAYMENT_STATUS_FILTERS,
} from "@/features/orders/constants";
import { normalizeOrdersSearch } from "@/features/orders/search";
import type {
  OrderSort,
  OrderStatus,
  OrderStatusFilter,
  OrdersExplorerQuery,
  OrdersPagination,
  PaymentStatusFilter,
} from "@/features/orders/types";

type SearchParamsInput =
  | Record<string, string | string[] | undefined>
  | URLSearchParams;

export function parseOrdersPagination(
  searchParams: SearchParamsInput,
): OrdersPagination {
  const pageSize = clampInt(
    parseStrictPositiveInt(readSearchParam(searchParams, "pageSize")),
    1,
    ORDERS_PAGE_SIZE_MAX,
    ORDERS_PAGE_SIZE_DEFAULT,
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

export function parseOrdersExplorerQuery(
  searchParams: SearchParamsInput,
): OrdersExplorerQuery {
  const search = normalizeOrdersSearch(
    readSearchParam(searchParams, "q") ?? "",
  );
  const statusRaw = (readSearchParam(searchParams, "status") ?? "").trim();
  const paymentRaw = (
    readSearchParam(searchParams, "paymentStatus") ?? ""
  ).trim();
  const sortRaw = (readSearchParam(searchParams, "sort") ?? "").trim();
  const placedFrom = parseOptionalIsoDateTime(
    readSearchParam(searchParams, "placedFrom"),
  );
  const placedTo = parseOptionalIsoDateTime(
    readSearchParam(searchParams, "placedTo"),
  );

  let resolvedFrom = placedFrom;
  let resolvedTo = placedTo;
  if (
    resolvedFrom !== null &&
    resolvedTo !== null &&
    resolvedFrom > resolvedTo
  ) {
    resolvedFrom = null;
    resolvedTo = null;
  }

  return {
    search,
    status: isOrderStatusFilter(statusRaw) ? statusRaw : ORDERS_DEFAULT_STATUS,
    paymentStatus: isPaymentStatusFilter(paymentRaw)
      ? paymentRaw
      : ORDERS_DEFAULT_PAYMENT_STATUS,
    placedFrom: resolvedFrom,
    placedTo: resolvedTo,
    sort: isOrderSort(sortRaw) ? sortRaw : ORDERS_DEFAULT_SORT,
    pagination: parseOrdersPagination(searchParams),
  };
}

export function ordersExplorerHasActiveFilters(
  query: OrdersExplorerQuery,
): boolean {
  return Boolean(
    query.search ||
      query.status !== ORDERS_DEFAULT_STATUS ||
      query.paymentStatus !== ORDERS_DEFAULT_PAYMENT_STATUS ||
      query.placedFrom ||
      query.placedTo ||
      query.sort !== ORDERS_DEFAULT_SORT,
  );
}

export function getOrdersExplorerRpcArgs(query: OrdersExplorerQuery) {
  return {
    p_search: query.search,
    p_status: query.status,
    p_payment_status: query.paymentStatus,
    p_placed_from: query.placedFrom,
    p_placed_to: query.placedTo,
    p_sort: query.sort,
    p_offset: query.pagination.from,
    p_limit: query.pagination.pageSize,
  };
}

export function ordersExplorerHref(
  query: Pick<
    OrdersExplorerQuery,
    "search" | "status" | "paymentStatus" | "placedFrom" | "placedTo" | "sort"
  > & {
    pagination?: Pick<OrdersPagination, "page" | "pageSize">;
  },
): string {
  const params = new URLSearchParams();
  const page = query.pagination?.page ?? 1;
  const pageSize = query.pagination?.pageSize;

  if (query.search) {
    params.set("q", query.search);
  }
  if (query.status !== ORDERS_DEFAULT_STATUS) {
    params.set("status", query.status);
  }
  if (query.paymentStatus !== ORDERS_DEFAULT_PAYMENT_STATUS) {
    params.set("paymentStatus", query.paymentStatus);
  }
  if (query.placedFrom) {
    params.set("placedFrom", query.placedFrom);
  }
  if (query.placedTo) {
    params.set("placedTo", query.placedTo);
  }
  if (query.sort !== ORDERS_DEFAULT_SORT) {
    params.set("sort", query.sort);
  }
  if (pageSize && pageSize !== ORDERS_PAGE_SIZE_DEFAULT) {
    params.set("pageSize", String(pageSize));
  }
  if (page > 1) {
    params.set("page", String(page));
  }

  const encoded = params.toString();
  return encoded ? `${ORDERS_LIST_PATH}?${encoded}` : ORDERS_LIST_PATH;
}

export function isOrderStatus(value: string): value is OrderStatus {
  return (ORDER_STATUSES as readonly string[]).includes(value);
}

export function isOrderStatusFilter(value: string): value is OrderStatusFilter {
  return (ORDER_STATUS_FILTERS as readonly string[]).includes(value);
}

export function isPaymentStatusFilter(
  value: string,
): value is PaymentStatusFilter {
  return (PAYMENT_STATUS_FILTERS as readonly string[]).includes(value);
}

export function isOrderSort(value: string): value is OrderSort {
  return (ORDER_SORTS as readonly string[]).includes(value);
}

export function getNextOrderStatuses(status: OrderStatus): OrderStatus[] {
  return [...ORDER_TRANSITIONS[status]];
}

export function isAllowedOrderTransition(
  from: OrderStatus,
  to: OrderStatus,
): boolean {
  return (ORDER_TRANSITIONS[from] as readonly string[]).includes(to);
}

export function normalizeOrderNote(raw: string): string | null {
  const collapsed = raw.trim().replace(/\s+/g, " ");
  if (!collapsed) {
    return null;
  }
  return collapsed.slice(0, ORDERS_NOTE_MAX_LENGTH);
}

function parseOptionalIsoDateTime(raw: string | undefined): string | null {
  if (raw === undefined) {
    return null;
  }
  const trimmed = raw.trim();
  if (!trimmed || trimmed.length > 40) {
    return null;
  }
  if (!/^\d{4}-\d{2}-\d{2}(T[\d:.+-Z]+)?$/.test(trimmed)) {
    return null;
  }
  const parsed = Date.parse(trimmed);
  if (!Number.isFinite(parsed)) {
    return null;
  }
  return new Date(parsed).toISOString();
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
