import { beforeEach, describe, expect, it, vi } from "vitest";

import {
  DASHBOARD_AUTH_DENIED_MESSAGE,
  DASHBOARD_LOAD_FAILURE_MESSAGE,
} from "@/features/operational-dashboard/constants";
import { buildOperationalDashboardRpcPayload } from "@/features/operational-dashboard/test-fixtures";

const authorizeCmsRequest = vi.hoisted(() => vi.fn());

vi.mock("@/lib/auth/authorization", async () => {
  const actual = await vi.importActual<
    typeof import("@/lib/auth/authorization")
  >("@/lib/auth/authorization");
  return { ...actual, authorizeCmsRequest };
});

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
      query: { rangeDays: 7 },
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
          data: [{ range_days: 7 }],
          error: null,
        }),
      } as never,
      query: { rangeDays: 7 },
    });

    expect(result).toEqual({
      ok: false,
      message: DASHBOARD_LOAD_FAILURE_MESSAGE,
    });
  });

  it("fails closed when the RPC returns an incomplete daily series", async () => {
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
          data: buildOperationalDashboardRpcPayload({
            daily_series_by_currency: [
              {
                currency_code: "USD",
                series: [
                  {
                    date: "2026-08-23",
                    order_count: 1,
                    gross_order_value: 150,
                  },
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
          error: null,
        }),
      } as never,
      query: { rangeDays: 7 },
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
          data: buildOperationalDashboardRpcPayload(),
          error: null,
        }),
      } as never,
      query: { rangeDays: 7 },
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
    expect(result.snapshot.dailySeriesByCurrency[0]?.series).toHaveLength(8);
    expect(
      result.snapshot.grossOrderValueByCurrency[0]?.grossOrderValueLabel,
    ).toContain("US$");
    expect(
      result.snapshot.grossOrderValueByCurrency[1]?.grossOrderValueLabel,
    ).toContain("₫");
  });
});
