import { beforeEach, describe, expect, it, vi } from "vitest";

import {
  DASHBOARD_AUTH_DENIED_MESSAGE,
  DASHBOARD_LOAD_FAILURE_MESSAGE,
} from "@/features/operational-dashboard/constants";

const authorizeCmsRequest = vi.hoisted(() => vi.fn());

vi.mock("@/lib/auth/authorization", async () => {
  const actual = await vi.importActual<
    typeof import("@/lib/auth/authorization")
  >("@/lib/auth/authorization");
  return { ...actual, authorizeCmsRequest };
});

function buildRpcPayload() {
  return [
    {
      range_days: 30,
      window_start: "2026-07-24T12:00:00.000Z",
      window_end: "2026-08-23T12:00:00.000Z",
      total_orders: 2,
      gross_order_value_by_currency: [
        { currency_code: "USD", gross_order_value: 150 },
        { currency_code: "VND", gross_order_value: 500000 },
      ],
      delivered_orders: 1,
      open_fulfillment_count: 1,
      status_breakdown: [
        { status: "pending", order_count: 1 },
        { status: "confirmed", order_count: 0 },
        { status: "preparing", order_count: 0 },
        { status: "shipping", order_count: 0 },
        { status: "delivered", order_count: 1 },
        { status: "cancelled", order_count: 0 },
        { status: "returned", order_count: 0 },
      ],
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
            { date: "2026-08-23", order_count: 1, gross_order_value: 500000 },
          ],
        },
      ],
      low_stock_variants: [],
    },
  ];
}

describe("getOperationalDashboard", () => {
  beforeEach(() => {
    authorizeCmsRequest.mockReset();
  });

  it("authorizes before calling the dashboard RPC", async () => {
    const rpc = vi.fn();
    authorizeCmsRequest.mockResolvedValue({ kind: "unauthorized" });

    const { getOperationalDashboard } = await import(
      "@/features/operational-dashboard/queries"
    );
    const result = await getOperationalDashboard({
      supabase: { auth: { getClaims: vi.fn() }, rpc } as never,
      query: { rangeDays: 30 },
    });

    expect(result).toEqual({
      ok: false,
      message: DASHBOARD_AUTH_DENIED_MESSAGE,
    });
    expect(rpc).not.toHaveBeenCalled();
  });

  it("fails closed on invalid RPC payloads", async () => {
    authorizeCmsRequest.mockResolvedValue({
      kind: "authorized",
      profile: {
        id: "staff-1",
        fullName: "Alex Coach",
        role: "staff",
        isActive: true,
      },
    });

    const { getOperationalDashboard } = await import(
      "@/features/operational-dashboard/queries"
    );
    const result = await getOperationalDashboard({
      supabase: {
        auth: { getClaims: vi.fn() },
        rpc: vi.fn().mockResolvedValue({
          data: [{ range_days: 30 }],
          error: null,
        }),
      } as never,
      query: { rangeDays: 30 },
    });

    expect(result).toEqual({
      ok: false,
      message: DASHBOARD_LOAD_FAILURE_MESSAGE,
    });
  });

  it("maps currency-aware gross metrics without mixing currencies", async () => {
    authorizeCmsRequest.mockResolvedValue({
      kind: "authorized",
      profile: {
        id: "staff-1",
        fullName: "Alex Coach",
        role: "staff",
        isActive: true,
      },
    });

    const { getOperationalDashboard } = await import(
      "@/features/operational-dashboard/queries"
    );
    const result = await getOperationalDashboard({
      supabase: {
        auth: { getClaims: vi.fn() },
        rpc: vi.fn().mockResolvedValue({
          data: buildRpcPayload(),
          error: null,
        }),
      } as never,
      query: { rangeDays: 30 },
    });

    expect(result.ok).toBe(true);
    if (!result.ok) {
      return;
    }

    expect(result.snapshot.grossOrderValueByCurrency).toEqual([
      expect.objectContaining({
        currencyCode: "USD",
        grossOrderValue: 150,
      }),
      expect.objectContaining({
        currencyCode: "VND",
        grossOrderValue: 500000,
      }),
    ]);
    expect(
      result.snapshot.grossOrderValueByCurrency[0]?.grossOrderValueLabel,
    ).toContain("US$");
    expect(
      result.snapshot.grossOrderValueByCurrency[1]?.grossOrderValueLabel,
    ).toContain("₫");
  });
});
