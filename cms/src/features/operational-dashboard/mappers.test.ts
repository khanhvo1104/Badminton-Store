import { describe, expect, it } from "vitest";

import {
  buildOperationalDashboardSnapshot,
  formatMoney,
  mapOperationalDashboardRpcRow,
} from "@/features/operational-dashboard/mappers";

const VARIANT_ID = "40000000-0000-4000-8000-000000000001";
const PRODUCT_ID = "30000000-0000-4000-8000-000000000001";

function buildRpcPayload(overrides: Record<string, unknown> = {}) {
  return [
    {
      range_days: 30,
      window_start: "2026-07-24T12:00:00.000Z",
      window_end: "2026-08-23T12:00:00.000Z",
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
        {
          currency_code: "USD",
          series: [
            { date: "2026-08-22", order_count: 1, gross_order_value: 150 },
            { date: "2026-08-23", order_count: 0, gross_order_value: 0 },
          ],
        },
        {
          currency_code: "VND",
          series: [
            { date: "2026-08-22", order_count: 1, gross_order_value: 300000 },
            { date: "2026-08-23", order_count: 1, gross_order_value: 200000 },
          ],
        },
      ],
      low_stock_variants: [
        {
          variant_id: VARIANT_ID,
          product_id: PRODUCT_ID,
          product_name: "Aero",
          variant_name: "Red",
          sku: "SKU-1",
          quantity_on_hand: 5,
          quantity_reserved: 4,
          quantity_available: 1,
          reorder_level: 2,
          allow_backorder: false,
        },
      ],
      ...overrides,
    },
  ];
}

describe("mapOperationalDashboardRpcRow", () => {
  it("maps a valid currency-aware payload without forbidden fields", () => {
    const mapped = mapOperationalDashboardRpcRow(buildRpcPayload());
    expect(mapped).not.toBeNull();
    expect(mapped?.gross_order_value_by_currency).toEqual([
      { currency_code: "USD", gross_order_value: 150 },
      { currency_code: "VND", gross_order_value: 500000 },
    ]);
  });

  it("rejects payloads with forbidden PII or cost fields", () => {
    expect(
      mapOperationalDashboardRpcRow(
        buildRpcPayload({ recipient_name: "Hidden" }),
      ),
    ).toBeNull();
    expect(
      mapOperationalDashboardRpcRow(buildRpcPayload({ cost_price: 10 })),
    ).toBeNull();
  });

  it("rejects unsorted currency groups", () => {
    expect(
      mapOperationalDashboardRpcRow(
        buildRpcPayload({
          gross_order_value_by_currency: [
            { currency_code: "VND", gross_order_value: 1 },
            { currency_code: "USD", gross_order_value: 2 },
          ],
        }),
      ),
    ).toBeNull();
  });

  it("rejects daily series with out-of-order UTC dates", () => {
    expect(
      mapOperationalDashboardRpcRow(
        buildRpcPayload({
          daily_series_by_currency: [
            {
              currency_code: "USD",
              series: [
                { date: "2026-08-23", order_count: 0, gross_order_value: 0 },
                { date: "2026-08-22", order_count: 1, gross_order_value: 150 },
              ],
            },
          ],
        }),
      ),
    ).toBeNull();
  });

  it("rejects invalid range values", () => {
    expect(
      mapOperationalDashboardRpcRow(buildRpcPayload({ range_days: 14 })),
    ).toBeNull();
  });
});

describe("buildOperationalDashboardSnapshot", () => {
  it("formats each gross metric with its own currency code", () => {
    const mapped = mapOperationalDashboardRpcRow(buildRpcPayload());
    expect(mapped).not.toBeNull();
    const snapshot = buildOperationalDashboardSnapshot(mapped!);

    expect(snapshot.grossOrderValueByCurrency).toEqual([
      {
        currencyCode: "USD",
        grossOrderValue: 150,
        grossOrderValueLabel: formatMoney(150, "USD"),
      },
      {
        currencyCode: "VND",
        grossOrderValue: 500000,
        grossOrderValueLabel: formatMoney(500000, "VND"),
      },
    ]);
    expect(
      snapshot.dailySeriesByCurrency[0]?.series[0]?.grossOrderValueLabel,
    ).toBe(formatMoney(150, "USD"));
    expect(
      snapshot.dailySeriesByCurrency[1]?.series[0]?.grossOrderValueLabel,
    ).toBe(formatMoney(300000, "VND"));
  });
});

describe("formatMoney", () => {
  it("uses the provided currency code instead of a hard-coded default", () => {
    expect(formatMoney(150, "USD")).toContain("US$");
    expect(formatMoney(500000, "VND")).toContain("₫");
  });
});
