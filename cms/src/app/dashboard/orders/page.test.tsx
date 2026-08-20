import { render, screen } from "@testing-library/react";
import { describe, expect, it, vi } from "vitest";

vi.mock("next/navigation", () => ({
  notFound: () => {
    throw new Error("NEXT_NOT_FOUND");
  },
}));

vi.mock("@/lib/supabase/server", () => ({
  createSupabaseServerClient: vi.fn(async () => ({})),
}));

vi.mock("@/lib/auth/authorization", () => ({
  authorizeCmsRequest: vi.fn(async () => ({
    kind: "authorized",
    profile: {
      id: "staff-1",
      fullName: "Alex Coach",
      role: "staff",
      isActive: true,
    },
  })),
}));

vi.mock("@/features/orders/queries", () => ({
  listOrders: vi.fn(async () => ({
    ok: true,
    result: {
      items: [],
      totalCount: 0,
      pagination: { page: 1, pageSize: 20, from: 0, to: 19 },
      totalPages: 0,
      query: {
        search: "",
        status: "all",
        paymentStatus: "all",
        placedFrom: null,
        placedTo: null,
        sort: "placed_desc",
        pagination: { page: 1, pageSize: 20, from: 0, to: 19 },
      },
      hasActiveFilters: false,
    },
  })),
  getOrderDetail: vi.fn(async () => ({
    ok: false,
    message: "That order could not be found.",
    notFound: true,
  })),
}));

describe("orders pages", () => {
  it("renders the explorer shell and empty state", async () => {
    const { default: OrdersPage } = await import("@/app/dashboard/orders/page");
    const element = await OrdersPage({ searchParams: Promise.resolve({}) });
    render(element);

    expect(screen.getByRole("heading", { name: "Orders" })).toBeInTheDocument();
    expect(screen.getByRole("search")).toBeInTheDocument();
    expect(screen.getByText(/no orders yet/i)).toBeInTheDocument();
  });

  it("uses not-found for invalid or missing order ids", async () => {
    const { default: OrderDetailPage } = await import(
      "@/app/dashboard/orders/[orderId]/page"
    );

    await expect(
      OrderDetailPage({
        params: Promise.resolve({ orderId: "not-a-uuid" }),
        searchParams: Promise.resolve({}),
      }),
    ).rejects.toThrow("NEXT_NOT_FOUND");

    await expect(
      OrderDetailPage({
        params: Promise.resolve({
          orderId: "40000000-0000-4000-8000-000000000001",
        }),
        searchParams: Promise.resolve({}),
      }),
    ).rejects.toThrow("NEXT_NOT_FOUND");
  });
});
