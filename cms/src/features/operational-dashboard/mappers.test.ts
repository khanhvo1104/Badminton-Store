import { describe, expect, it } from "vitest";

import {
  buildOperationalDashboardSnapshot,
  formatMoney,
  mapOperationalDashboardRpcRow,
} from "@/features/operational-dashboard/mappers";
import {
  buildUtcDateSeries,
  getExpectedDailySeriesLength,
  resolveUtcWindowBounds,
} from "@/features/operational-dashboard/series";
import {
  buildOperationalDashboardRpcPayload,
  TEST_WINDOW,
  TEST_VARIANT_ID,
} from "@/features/operational-dashboard/test-fixtures";

describe("resolveUtcWindowBounds", () => {
  it("expects range_days + 1 consecutive UTC dates", () => {
    expect(
      resolveUtcWindowBounds(
        TEST_WINDOW.rangeDays,
        TEST_WINDOW.windowStart,
        TEST_WINDOW.windowEnd,
      ),
    ).toEqual({
      startDate: TEST_WINDOW.startDate,
      endDate: TEST_WINDOW.endDate,
      expectedSeriesLength: getExpectedDailySeriesLength(TEST_WINDOW.rangeDays),
    });
  });
});

describe("mapOperationalDashboardRpcRow", () => {
  it("maps a valid currency-aware payload without forbidden fields", () => {
    const mapped = mapOperationalDashboardRpcRow(
      buildOperationalDashboardRpcPayload(),
    );
    expect(mapped).not.toBeNull();
    expect(mapped?.gross_order_value_by_currency).toEqual([
      { currency_code: "USD", gross_order_value: 150 },
      { currency_code: "VND", gross_order_value: 500000 },
    ]);
    expect(mapped?.daily_series_by_currency[0]?.series).toHaveLength(8);
  });

  it("rejects payloads with forbidden PII or cost fields", () => {
    expect(
      mapOperationalDashboardRpcRow(
        buildOperationalDashboardRpcPayload({ recipient_name: "Hidden" }),
      ),
    ).toBeNull();
    expect(
      mapOperationalDashboardRpcRow(
        buildOperationalDashboardRpcPayload({ cost_price: 10 }),
      ),
    ).toBeNull();
  });

  it("rejects incomplete daily series for the documented window", () => {
    expect(
      mapOperationalDashboardRpcRow(
        buildOperationalDashboardRpcPayload({
          daily_series_by_currency: [
            {
              currency_code: "USD",
              series: [
                { date: "2026-08-23", order_count: 1, gross_order_value: 150 },
              ],
            },
            {
              currency_code: "VND",
              series: [
                {
                  date: "2026-08-23",
                  order_count: 1,
                  gross_order_value: 500000,
                },
              ],
            },
          ],
        }),
      ),
    ).toBeNull();
  });

  it("rejects daily series with bad UTC window endpoints", () => {
    expect(
      mapOperationalDashboardRpcRow(
        buildOperationalDashboardRpcPayload({
          daily_series_by_currency: [
            {
              currency_code: "USD",
              series: buildUtcDateSeries("2026-08-17", 8).map((date) => ({
                date,
                order_count: 0,
                gross_order_value: 0,
              })),
            },
            {
              currency_code: "VND",
              series: buildUtcDateSeries(TEST_WINDOW.startDate, 8).map(
                (date) => ({
                  date,
                  order_count: 0,
                  gross_order_value: 0,
                }),
              ),
            },
          ],
        }),
      ),
    ).toBeNull();
  });

  it("rejects currency-set mismatches between gross totals and daily series", () => {
    const payload = buildOperationalDashboardRpcPayload();
    const dailyOnly = payload[0]?.daily_series_by_currency;
    expect(
      mapOperationalDashboardRpcRow(
        buildOperationalDashboardRpcPayload({
          gross_order_value_by_currency: [
            { currency_code: "USD", gross_order_value: 150 },
          ],
          daily_series_by_currency: dailyOnly,
        }),
      ),
    ).toBeNull();
  });

  it("rejects unsorted currency groups", () => {
    expect(
      mapOperationalDashboardRpcRow(
        buildOperationalDashboardRpcPayload({
          gross_order_value_by_currency: [
            { currency_code: "VND", gross_order_value: 1 },
            { currency_code: "USD", gross_order_value: 2 },
          ],
        }),
      ),
    ).toBeNull();
  });

  it("rejects invalid range values and inconsistent window bounds", () => {
    expect(
      mapOperationalDashboardRpcRow(
        buildOperationalDashboardRpcPayload({ range_days: 14 }),
      ),
    ).toBeNull();
    expect(
      mapOperationalDashboardRpcRow(
        buildOperationalDashboardRpcPayload({
          window_end: "2026-08-20T12:00:00.000Z",
        }),
      ),
    ).toBeNull();
  });

  it("accepts signed low-stock availability and validates on_hand - reserved", () => {
    const mapped = mapOperationalDashboardRpcRow(
      buildOperationalDashboardRpcPayload(),
    );
    expect(mapped).not.toBeNull();
    expect(
      mapped?.low_stock_variants.find(
        (entry) => entry.variant_id === TEST_VARIANT_ID,
      ),
    ).toMatchObject({
      quantity_on_hand: 5,
      quantity_reserved: 4,
      quantity_available: 1,
      reorder_level: 2,
    });
    expect(
      mapped?.low_stock_variants.some(
        (entry) => entry.quantity_available === -3,
      ),
    ).toBe(true);
  });

  it("rejects low-stock rows where available drifts from on_hand - reserved", () => {
    expect(
      mapOperationalDashboardRpcRow(
        buildOperationalDashboardRpcPayload({
          low_stock_variants: [
            {
              variant_id: TEST_VARIANT_ID,
              product_id: "30000000-0000-4000-8000-000000000001",
              product_name: "Aero",
              variant_name: "Red",
              sku: "SKU-1",
              quantity_on_hand: 5,
              quantity_reserved: 4,
              quantity_available: 0,
              reorder_level: 2,
              allow_backorder: false,
            },
          ],
        }),
      ),
    ).toBeNull();
  });
});

describe("buildOperationalDashboardSnapshot", () => {
  it("formats each gross metric with its own currency code", () => {
    const mapped = mapOperationalDashboardRpcRow(
      buildOperationalDashboardRpcPayload(),
    );
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
  });
});

describe("formatMoney", () => {
  it("uses the provided currency code instead of a hard-coded default", () => {
    expect(formatMoney(150, "USD")).toContain("US$");
    expect(formatMoney(500000, "VND")).toContain("₫");
  });
});
