import {
  DASHBOARD_FORBIDDEN_RPC_KEYS,
  DASHBOARD_MAX_CURRENCIES,
  DASHBOARD_MAX_DAILY_POINTS,
  DASHBOARD_MAX_LOW_STOCK_VARIANTS,
  DASHBOARD_RPC_ROW_KEYS,
  ORDER_STATUS_LABELS,
} from "@/features/operational-dashboard/constants";
import type {
  DashboardCurrencyGross,
  DashboardDailyPoint,
  DashboardDailySeriesByCurrency,
  DashboardLowStockVariant,
  DashboardRangeDays,
  DashboardStatusBreakdownItem,
  OperationalDashboardSnapshot,
} from "@/features/operational-dashboard/types";
import { isDashboardRangeDays } from "@/features/operational-dashboard/validation";
import { isValidUuid } from "@/features/products/validation";

const ORDER_STATUSES = Object.keys(
  ORDER_STATUS_LABELS,
) as (keyof typeof ORDER_STATUS_LABELS)[];

const ISO_DATE_PATTERN = /^\d{4}-\d{2}-\d{2}$/;
const CURRENCY_CODE_PATTERN = /^[A-Z]{3}$/;

export type CmsOperationalDashboardRpcRow = {
  range_days: DashboardRangeDays;
  window_start: string;
  window_end: string;
  total_orders: number;
  gross_order_value_by_currency: Array<{
    currency_code: string;
    gross_order_value: number;
  }>;
  delivered_orders: number;
  open_fulfillment_count: number;
  status_breakdown: Array<{
    status: keyof typeof ORDER_STATUS_LABELS;
    order_count: number;
  }>;
  daily_series_by_currency: Array<{
    currency_code: string;
    series: Array<{
      date: string;
      order_count: number;
      gross_order_value: number;
    }>;
  }>;
  low_stock_variants: Array<{
    variant_id: string;
    product_id: string;
    product_name: string;
    variant_name: string | null;
    sku: string;
    quantity_on_hand: number;
    quantity_reserved: number;
    quantity_available: number;
    reorder_level: number;
    allow_backorder: boolean;
  }>;
};

export function mapOperationalDashboardRpcRow(
  value: unknown,
): CmsOperationalDashboardRpcRow | null {
  if (!Array.isArray(value) || value.length !== 1) {
    return null;
  }

  const row = value[0];
  if (!isRecord(row)) {
    return null;
  }

  if (!hasExactKeys(row, DASHBOARD_RPC_ROW_KEYS)) {
    return null;
  }

  for (const forbiddenKey of DASHBOARD_FORBIDDEN_RPC_KEYS) {
    if (Object.prototype.hasOwnProperty.call(row, forbiddenKey)) {
      return null;
    }
  }

  const rangeDays = asInteger(row.range_days);
  if (!isDashboardRangeDays(rangeDays)) {
    return null;
  }

  const windowStart = asIsoDateTime(row.window_start);
  const windowEnd = asIsoDateTime(row.window_end);
  const totalOrders = asNonNegativeInteger(row.total_orders);
  const deliveredOrders = asNonNegativeInteger(row.delivered_orders);
  const openFulfillmentCount = asNonNegativeInteger(row.open_fulfillment_count);

  if (
    windowStart === null ||
    windowEnd === null ||
    totalOrders === null ||
    deliveredOrders === null ||
    openFulfillmentCount === null
  ) {
    return null;
  }

  const grossOrderValueByCurrency = mapGrossOrderValueByCurrency(
    row.gross_order_value_by_currency,
  );
  if (grossOrderValueByCurrency === null) {
    return null;
  }

  const statusBreakdown = mapStatusBreakdown(row.status_breakdown);
  if (statusBreakdown === null) {
    return null;
  }

  const dailySeriesByCurrency = mapDailySeriesByCurrency(
    row.daily_series_by_currency,
  );
  if (dailySeriesByCurrency === null) {
    return null;
  }

  const lowStockVariants = mapLowStockVariants(row.low_stock_variants);
  if (lowStockVariants === null) {
    return null;
  }

  return {
    range_days: rangeDays,
    window_start: windowStart,
    window_end: windowEnd,
    total_orders: totalOrders,
    gross_order_value_by_currency: grossOrderValueByCurrency,
    delivered_orders: deliveredOrders,
    open_fulfillment_count: openFulfillmentCount,
    status_breakdown: statusBreakdown,
    daily_series_by_currency: dailySeriesByCurrency,
    low_stock_variants: lowStockVariants,
  };
}

export function buildOperationalDashboardSnapshot(
  row: CmsOperationalDashboardRpcRow,
): OperationalDashboardSnapshot {
  return {
    rangeDays: row.range_days,
    windowStart: row.window_start,
    windowEnd: row.window_end,
    windowStartLabel: formatDateTime(row.window_start),
    windowEndLabel: formatDateTime(row.window_end),
    totalOrders: row.total_orders,
    grossOrderValueByCurrency: row.gross_order_value_by_currency.map(
      (entry) => ({
        currencyCode: entry.currency_code,
        grossOrderValue: entry.gross_order_value,
        grossOrderValueLabel: formatMoney(
          entry.gross_order_value,
          entry.currency_code,
        ),
      }),
    ),
    deliveredOrders: row.delivered_orders,
    openFulfillmentCount: row.open_fulfillment_count,
    statusBreakdown: row.status_breakdown.map((entry) => ({
      status: entry.status,
      orderCount: entry.order_count,
      statusLabel: ORDER_STATUS_LABELS[entry.status],
    })),
    dailySeriesByCurrency: row.daily_series_by_currency.map((entry) => ({
      currencyCode: entry.currency_code,
      series: entry.series.map((point) => ({
        date: point.date,
        orderCount: point.order_count,
        grossOrderValue: point.gross_order_value,
        grossOrderValueLabel: formatMoney(
          point.gross_order_value,
          entry.currency_code,
        ),
      })),
    })),
    lowStockVariants: row.low_stock_variants.map((entry) => ({
      variantId: entry.variant_id,
      productId: entry.product_id,
      productName: entry.product_name,
      variantName: entry.variant_name,
      sku: entry.sku,
      quantityOnHand: entry.quantity_on_hand,
      quantityReserved: entry.quantity_reserved,
      quantityAvailable: entry.quantity_available,
      reorderLevel: entry.reorder_level,
      allowBackorder: entry.allow_backorder,
    })),
  };
}

function mapGrossOrderValueByCurrency(
  value: unknown,
): CmsOperationalDashboardRpcRow["gross_order_value_by_currency"] | null {
  if (!Array.isArray(value)) {
    return null;
  }
  if (value.length > DASHBOARD_MAX_CURRENCIES) {
    return null;
  }

  const mapped: CmsOperationalDashboardRpcRow["gross_order_value_by_currency"] =
    [];

  for (const entry of value) {
    if (
      !isRecord(entry) ||
      !hasExactKeys(entry, ["currency_code", "gross_order_value"])
    ) {
      return null;
    }

    const currencyCode = asCurrencyCode(entry.currency_code);
    const grossOrderValue = asMoney(entry.gross_order_value);
    if (
      currencyCode === null ||
      grossOrderValue === null ||
      grossOrderValue < 0
    ) {
      return null;
    }

    mapped.push({
      currency_code: currencyCode,
      gross_order_value: grossOrderValue,
    });
  }

  if (!isSortedUnique(mapped.map((entry) => entry.currency_code))) {
    return null;
  }

  return mapped;
}

function mapStatusBreakdown(
  value: unknown,
): CmsOperationalDashboardRpcRow["status_breakdown"] | null {
  if (!Array.isArray(value) || value.length !== ORDER_STATUSES.length) {
    return null;
  }

  const mapped: CmsOperationalDashboardRpcRow["status_breakdown"] = [];
  const seen = new Set<string>();

  for (const entry of value) {
    if (!isRecord(entry) || !hasExactKeys(entry, ["status", "order_count"])) {
      return null;
    }

    const status = entry.status;
    if (typeof status !== "string" || !isOrderStatus(status)) {
      return null;
    }
    if (seen.has(status)) {
      return null;
    }
    seen.add(status);

    const orderCount = asNonNegativeInteger(entry.order_count);
    if (orderCount === null) {
      return null;
    }

    mapped.push({ status, order_count: orderCount });
  }

  if (seen.size !== ORDER_STATUSES.length) {
    return null;
  }

  return mapped;
}

function mapDailySeriesByCurrency(
  value: unknown,
): CmsOperationalDashboardRpcRow["daily_series_by_currency"] | null {
  if (!Array.isArray(value)) {
    return null;
  }
  if (value.length > DASHBOARD_MAX_CURRENCIES) {
    return null;
  }

  const mapped: CmsOperationalDashboardRpcRow["daily_series_by_currency"] = [];

  for (const entry of value) {
    if (!isRecord(entry) || !hasExactKeys(entry, ["currency_code", "series"])) {
      return null;
    }

    const currencyCode = asCurrencyCode(entry.currency_code);
    if (currencyCode === null) {
      return null;
    }

    const series = mapDailySeries(entry.series);
    if (series === null) {
      return null;
    }

    mapped.push({ currency_code: currencyCode, series });
  }

  if (!isSortedUnique(mapped.map((entry) => entry.currency_code))) {
    return null;
  }

  return mapped;
}

function mapDailySeries(
  value: unknown,
):
  | CmsOperationalDashboardRpcRow["daily_series_by_currency"][number]["series"]
  | null {
  if (!Array.isArray(value)) {
    return null;
  }
  if (value.length < 1 || value.length > DASHBOARD_MAX_DAILY_POINTS) {
    return null;
  }

  const mapped: CmsOperationalDashboardRpcRow["daily_series_by_currency"][number]["series"] =
    [];
  let previousDate: string | null = null;

  for (const entry of value) {
    if (
      !isRecord(entry) ||
      !hasExactKeys(entry, ["date", "order_count", "gross_order_value"])
    ) {
      return null;
    }

    const date = asIsoDate(entry.date);
    const orderCount = asNonNegativeInteger(entry.order_count);
    const grossOrderValue = asMoney(entry.gross_order_value);

    if (
      date === null ||
      orderCount === null ||
      grossOrderValue === null ||
      grossOrderValue < 0
    ) {
      return null;
    }

    if (previousDate !== null && date <= previousDate) {
      return null;
    }
    previousDate = date;

    mapped.push({
      date,
      order_count: orderCount,
      gross_order_value: grossOrderValue,
    });
  }

  return mapped;
}

function mapLowStockVariants(
  value: unknown,
): CmsOperationalDashboardRpcRow["low_stock_variants"] | null {
  if (!Array.isArray(value)) {
    return null;
  }
  if (value.length > DASHBOARD_MAX_LOW_STOCK_VARIANTS) {
    return null;
  }

  const mapped: CmsOperationalDashboardRpcRow["low_stock_variants"] = [];

  for (const entry of value) {
    if (
      !isRecord(entry) ||
      !hasExactKeys(entry, [
        "variant_id",
        "product_id",
        "product_name",
        "variant_name",
        "sku",
        "quantity_on_hand",
        "quantity_reserved",
        "quantity_available",
        "reorder_level",
        "allow_backorder",
      ])
    ) {
      return null;
    }

    const variantId = asUuid(entry.variant_id);
    const productId = asUuid(entry.product_id);
    const productName = asNonEmptyText(entry.product_name);
    const variantName = asNullableText(entry.variant_name);
    const sku = asNonEmptyText(entry.sku);
    const quantityOnHand = asNonNegativeInteger(entry.quantity_on_hand);
    const quantityReserved = asNonNegativeInteger(entry.quantity_reserved);
    const quantityAvailable = asNonNegativeInteger(entry.quantity_available);
    const reorderLevel = asNonNegativeInteger(entry.reorder_level);
    const allowBackorder = entry.allow_backorder;

    if (
      variantId === null ||
      productId === null ||
      productName === null ||
      sku === null ||
      quantityOnHand === null ||
      quantityReserved === null ||
      quantityAvailable === null ||
      reorderLevel === null ||
      typeof allowBackorder !== "boolean"
    ) {
      return null;
    }

    mapped.push({
      variant_id: variantId,
      product_id: productId,
      product_name: productName,
      variant_name: variantName,
      sku,
      quantity_on_hand: quantityOnHand,
      quantity_reserved: quantityReserved,
      quantity_available: quantityAvailable,
      reorder_level: reorderLevel,
      allow_backorder: allowBackorder,
    });
  }

  return mapped;
}

export function formatMoney(value: number, currencyCode: string): string {
  try {
    return new Intl.NumberFormat("vi-VN", {
      style: "currency",
      currency: currencyCode,
      maximumFractionDigits: 0,
    }).format(value);
  } catch {
    return `${value} ${currencyCode}`;
  }
}

function formatDateTime(value: string): string {
  const date = new Date(value);
  if (!Number.isFinite(date.getTime())) {
    return value;
  }
  return new Intl.DateTimeFormat("en-GB", {
    dateStyle: "medium",
    timeStyle: "short",
    timeZone: "UTC",
  }).format(date);
}

function isOrderStatus(
  value: string,
): value is keyof typeof ORDER_STATUS_LABELS {
  return Object.prototype.hasOwnProperty.call(ORDER_STATUS_LABELS, value);
}

function isSortedUnique(values: string[]): boolean {
  for (let index = 1; index < values.length; index += 1) {
    if (values[index] <= values[index - 1]) {
      return false;
    }
  }
  return true;
}

function hasExactKeys(
  value: Record<string, unknown>,
  keys: readonly string[],
): boolean {
  const actualKeys = Object.keys(value);
  if (actualKeys.length !== keys.length) {
    return false;
  }
  return keys.every((key) => Object.prototype.hasOwnProperty.call(value, key));
}

function asInteger(value: unknown): number | null {
  if (typeof value === "number" && Number.isInteger(value)) {
    return value;
  }
  if (typeof value === "string" && /^-?\d+$/.test(value)) {
    const parsed = Number(value);
    return Number.isSafeInteger(parsed) ? parsed : null;
  }
  return null;
}

function asNonNegativeInteger(value: unknown): number | null {
  const parsed = asInteger(value);
  if (parsed === null || parsed < 0) {
    return null;
  }
  return parsed;
}

function asMoney(value: unknown): number | null {
  if (typeof value === "number" && Number.isFinite(value)) {
    return value;
  }
  if (typeof value === "string" && value.trim() !== "") {
    const parsed = Number(value);
    return Number.isFinite(parsed) ? parsed : null;
  }
  return null;
}

function asIsoDateTime(value: unknown): string | null {
  if (typeof value !== "string" || !value.trim()) {
    return null;
  }
  const parsed = new Date(value);
  if (!Number.isFinite(parsed.getTime())) {
    return null;
  }
  return value;
}

function asIsoDate(value: unknown): string | null {
  if (typeof value !== "string" || !ISO_DATE_PATTERN.test(value)) {
    return null;
  }
  const parsed = new Date(`${value}T00:00:00.000Z`);
  if (!Number.isFinite(parsed.getTime())) {
    return null;
  }
  return value;
}

function asCurrencyCode(value: unknown): string | null {
  if (typeof value !== "string" || !CURRENCY_CODE_PATTERN.test(value)) {
    return null;
  }
  return value;
}

function asUuid(value: unknown): string | null {
  return typeof value === "string" && isValidUuid(value) ? value : null;
}

function asNonEmptyText(value: unknown): string | null {
  if (typeof value !== "string") {
    return null;
  }
  const trimmed = value.trim();
  return trimmed ? trimmed : null;
}

function asNullableText(value: unknown): string | null {
  if (value === null) {
    return null;
  }
  return typeof value === "string" ? value : null;
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null;
}

export type {
  DashboardCurrencyGross,
  DashboardDailyPoint,
  DashboardDailySeriesByCurrency,
  DashboardLowStockVariant,
  DashboardStatusBreakdownItem,
};
