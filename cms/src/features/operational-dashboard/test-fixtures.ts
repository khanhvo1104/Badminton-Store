import {
  buildUtcDateSeries,
  getExpectedDailySeriesLength,
} from "@/features/operational-dashboard/series";
import type { DashboardRangeDays } from "@/features/operational-dashboard/types";

export const TEST_VARIANT_ID = "40000000-0000-4000-8000-000000000001";
export const TEST_PRODUCT_ID = "30000000-0000-4000-8000-000000000001";

export const TEST_WINDOW = {
  rangeDays: 7 as DashboardRangeDays,
  windowStart: "2026-08-16T12:00:00.000Z",
  windowEnd: "2026-08-23T12:00:00.000Z",
  startDate: "2026-08-16",
  endDate: "2026-08-23",
};

function buildDailyPoint(
  date: string,
  overrides: Partial<{
    order_count: number;
    gross_order_value: number;
  }> = {},
) {
  return {
    date,
    order_count: overrides.order_count ?? 0,
    gross_order_value: overrides.gross_order_value ?? 0,
  };
}

export function buildCurrencySeries(
  currencyCode: "EUR" | "USD" | "VND",
  pointOverrides: Record<
    string,
    Partial<{
      order_count: number;
      gross_order_value: number;
    }>
  > = {},
) {
  const dates = buildUtcDateSeries(
    TEST_WINDOW.startDate,
    getExpectedDailySeriesLength(TEST_WINDOW.rangeDays),
  );

  return {
    currency_code: currencyCode,
    series: dates.map((date) =>
      buildDailyPoint(date, pointOverrides[date] ?? {}),
    ),
  };
}

export function buildOperationalDashboardRpcPayload(
  overrides: Record<string, unknown> = {},
) {
  return [
    {
      range_days: TEST_WINDOW.rangeDays,
      window_start: TEST_WINDOW.windowStart,
      window_end: TEST_WINDOW.windowEnd,
      total_orders: 3,
      gross_order_value_by_currency: [
        { currency_code: "USD", gross_order_value: 150 },
        { currency_code: "VND", gross_order_value: 500000 },
      ],
      delivered_orders: 1,
      open_fulfillment_count: 2,
      status_breakdown: [
        { status: "pending", order_count: 1 },
        { status: "confirmed", order_count: 0 },
        { status: "preparing", order_count: 0 },
        { status: "shipping", order_count: 1 },
        { status: "delivered", order_count: 1 },
        { status: "cancelled", order_count: 0 },
        { status: "returned", order_count: 0 },
      ],
      daily_series_by_currency: [
        buildCurrencySeries("USD", {
          "2026-08-22": { order_count: 1, gross_order_value: 150 },
        }),
        buildCurrencySeries("VND", {
          "2026-08-22": { order_count: 1, gross_order_value: 300000 },
          "2026-08-23": { order_count: 1, gross_order_value: 200000 },
        }),
      ],
      low_stock_variants: [
        {
          variant_id: TEST_VARIANT_ID,
          product_id: TEST_PRODUCT_ID,
          product_name: "Aero",
          variant_name: "Red",
          sku: "SKU-1",
          quantity_on_hand: 5,
          quantity_reserved: 4,
          quantity_available: 1,
          reorder_level: 2,
          allow_backorder: false,
        },
        {
          variant_id: "40000000-0000-4000-8000-000000000002",
          product_id: TEST_PRODUCT_ID,
          product_name: "Aero",
          variant_name: "Backorder",
          sku: "SKU-NEG",
          quantity_on_hand: 2,
          quantity_reserved: 5,
          quantity_available: -3,
          reorder_level: 0,
          allow_backorder: true,
        },
      ],
      ...overrides,
    },
  ];
}
