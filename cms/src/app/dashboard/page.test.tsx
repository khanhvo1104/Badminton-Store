import { render, screen } from "@testing-library/react";
import { describe, expect, it, vi } from "vitest";

const createSupabaseServerClient = vi.hoisted(() => vi.fn());
const authorizeCmsRequest = vi.hoisted(() => vi.fn());
const getOperationalDashboard = vi.hoisted(() => vi.fn());

vi.mock("@/lib/supabase/server", () => ({
  createSupabaseServerClient,
}));

vi.mock("@/lib/auth/authorization", async () => {
  const actual = await vi.importActual<
    typeof import("@/lib/auth/authorization")
  >("@/lib/auth/authorization");
  return { ...actual, authorizeCmsRequest };
});

vi.mock("@/features/operational-dashboard/queries", () => ({
  getOperationalDashboard,
}));

describe("DashboardOverviewPage", () => {
  it("renders currency-aware KPIs from the server RPC", async () => {
    createSupabaseServerClient.mockResolvedValue({});
    authorizeCmsRequest.mockResolvedValue({
      kind: "authorized",
      profile: {
        id: "staff-1",
        fullName: "Alex Coach",
        role: "staff",
        isActive: true,
      },
    });
    getOperationalDashboard.mockResolvedValue({
      ok: true,
      snapshot: {
        rangeDays: 30,
        windowStart: "2026-07-24T12:00:00.000Z",
        windowEnd: "2026-08-23T12:00:00.000Z",
        windowStartLabel: "24 Jul 2026, 12:00",
        windowEndLabel: "23 Aug 2026, 12:00",
        totalOrders: 2,
        grossOrderValueByCurrency: [
          {
            currencyCode: "USD",
            grossOrderValue: 150,
            grossOrderValueLabel: "$150",
          },
          {
            currencyCode: "VND",
            grossOrderValue: 500000,
            grossOrderValueLabel: "500.000 ₫",
          },
        ],
        deliveredOrders: 1,
        openFulfillmentCount: 1,
        statusBreakdown: [
          {
            status: "pending",
            orderCount: 1,
            statusLabel: "Pending",
          },
          {
            status: "confirmed",
            orderCount: 0,
            statusLabel: "Confirmed",
          },
          {
            status: "preparing",
            orderCount: 0,
            statusLabel: "Preparing",
          },
          {
            status: "shipping",
            orderCount: 0,
            statusLabel: "Shipping",
          },
          {
            status: "delivered",
            orderCount: 1,
            statusLabel: "Delivered",
          },
          {
            status: "cancelled",
            orderCount: 0,
            statusLabel: "Cancelled",
          },
          {
            status: "returned",
            orderCount: 0,
            statusLabel: "Returned",
          },
        ],
        dailySeriesByCurrency: [
          {
            currencyCode: "USD",
            series: [
              {
                date: "2026-08-23",
                orderCount: 1,
                grossOrderValue: 150,
                grossOrderValueLabel: "$150",
              },
            ],
          },
          {
            currencyCode: "VND",
            series: [
              {
                date: "2026-08-23",
                orderCount: 1,
                grossOrderValue: 500000,
                grossOrderValueLabel: "500.000 ₫",
              },
            ],
          },
        ],
        lowStockVariants: [],
      },
    });

    const { default: DashboardOverviewPage } = await import(
      "@/app/dashboard/page"
    );
    const element = await DashboardOverviewPage({
      searchParams: Promise.resolve({}),
    });
    render(element);

    expect(
      screen.getByRole("heading", { name: "Operational overview" }),
    ).toBeInTheDocument();
    expect(screen.getAllByText("500.000 ₫").length).toBeGreaterThan(0);
    expect(screen.getAllByText(/150/).length).toBeGreaterThan(0);
    expect(
      screen.getByRole("heading", { name: "USD daily series" }),
    ).toBeInTheDocument();
    expect(
      screen.getByRole("heading", { name: "VND daily series" }),
    ).toBeInTheDocument();
    expect(
      screen.getByText(/never summed across currencies/i),
    ).toBeInTheDocument();
  });

  it("renders an empty low-stock state", async () => {
    createSupabaseServerClient.mockResolvedValue({});
    authorizeCmsRequest.mockResolvedValue({
      kind: "authorized",
      profile: {
        id: "staff-1",
        fullName: "Alex Coach",
        role: "staff",
        isActive: true,
      },
    });
    getOperationalDashboard.mockResolvedValue({
      ok: false,
      message: "Operational dashboard metrics could not be loaded.",
    });

    const { default: DashboardOverviewPage } = await import(
      "@/app/dashboard/page"
    );
    const element = await DashboardOverviewPage({
      searchParams: Promise.resolve({}),
    });
    render(element);

    expect(
      screen.getByRole("heading", { name: "Dashboard unavailable" }),
    ).toBeInTheDocument();
  });
});
