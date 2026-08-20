import { beforeEach, describe, expect, it, vi } from "vitest";

import {
  ORDERS_AUTH_DENIED_MESSAGE,
  ORDERS_HISTORY_LIMIT,
  ORDERS_ITEMS_LIMIT,
  ORDERS_LOAD_FAILURE_MESSAGE,
} from "@/features/orders/constants";

const authorizeCmsRequest = vi.hoisted(() => vi.fn());

vi.mock("@/lib/auth/authorization", async () => {
  const actual = await vi.importActual<
    typeof import("@/lib/auth/authorization")
  >("@/lib/auth/authorization");
  return { ...actual, authorizeCmsRequest };
});

const ORDER_ID = "40000000-0000-4000-8000-000000000099";

function buildOrderRow() {
  return {
    id: ORDER_ID,
    order_number: "BDM-1",
    status: "pending",
    payment_method: "cod",
    payment_status: "unpaid",
    currency_code: "USD",
    subtotal: 25,
    discount_total: 0,
    shipping_fee: 0,
    grand_total: 25,
    customer_note: null,
    recipient_name: "Pat",
    recipient_phone: "0900000000",
    shipping_address: {
      recipient_name: "Pat",
      phone_number: "0900000000",
    },
    placed_at: "2026-08-20T00:00:00.000Z",
    cancelled_at: null,
  };
}

function buildItemRow(idSuffix: string) {
  return {
    id: `50000000-0000-4000-8000-0000000000${idSuffix}`,
    order_id: ORDER_ID,
    product_id: "30000000-0000-4000-8000-000000000001",
    variant_id: "40000000-0000-4000-8000-000000000001",
    product_name: "Aero",
    variant_name: "Red",
    sku: "SKU-1",
    image_path: null,
    unit_price: 12.5,
    quantity: 2,
    line_total: 25,
    created_at: "2026-08-20T00:00:00.000Z",
  };
}

function buildHistoryRow(idSuffix: string) {
  return {
    id: `60000000-0000-4000-8000-0000000000${idSuffix}`,
    order_id: ORDER_ID,
    from_status: null,
    to_status: "pending",
    changed_by: null,
    note: null,
    created_at: "2026-08-20T00:00:00.000Z",
  };
}

describe("getOrderDetail", () => {
  beforeEach(() => {
    authorizeCmsRequest.mockReset();
  });

  it("authorizes before reading order detail", async () => {
    const from = vi.fn();
    const rpc = vi.fn();
    authorizeCmsRequest.mockResolvedValue({ kind: "unauthorized" });

    const { getOrderDetail } = await import("@/features/orders/queries");
    const result = await getOrderDetail({
      supabase: { auth: { getClaims: vi.fn() }, from, rpc } as never,
      orderId: ORDER_ID,
    });

    expect(result).toEqual({
      ok: false,
      message: ORDERS_AUTH_DENIED_MESSAGE,
    });
    expect(from).not.toHaveBeenCalled();
  });

  it("fetches items and history with limit plus one and fails closed on overflow", async () => {
    authorizeCmsRequest.mockResolvedValue({
      kind: "authorized",
      profile: {
        id: "staff-1",
        fullName: "Staff",
        role: "staff",
        isActive: true,
      },
    });

    const itemLimits: number[] = [];
    const historyLimits: number[] = [];

    const from = vi.fn((table: string) => {
      if (table === "orders") {
        return {
          select: () => ({
            eq: () => ({
              maybeSingle: async () => ({
                data: buildOrderRow(),
                error: null,
              }),
            }),
          }),
        };
      }

      if (table === "order_items") {
        return {
          select: () => ({
            eq: () => ({
              order: () => ({
                order: () => ({
                  limit: async (count: number) => {
                    itemLimits.push(count);
                    return {
                      data: Array.from(
                        { length: ORDERS_ITEMS_LIMIT + 1 },
                        (_, i) =>
                          buildItemRow(String(i).padStart(2, "0").slice(-2)),
                      ),
                      error: null,
                    };
                  },
                }),
              }),
            }),
          }),
        };
      }

      if (table === "order_status_history") {
        return {
          select: () => ({
            eq: () => ({
              order: () => ({
                order: () => ({
                  limit: async (count: number) => {
                    historyLimits.push(count);
                    return {
                      data: [buildHistoryRow("01")],
                      error: null,
                    };
                  },
                }),
              }),
            }),
          }),
        };
      }

      throw new Error(`unexpected table ${table}`);
    });

    const { getOrderDetail } = await import("@/features/orders/queries");
    const overflowItems = await getOrderDetail({
      supabase: {
        auth: { getClaims: vi.fn() },
        from,
        rpc: vi.fn(),
      } as never,
      orderId: ORDER_ID,
    });

    expect(itemLimits).toEqual([ORDERS_ITEMS_LIMIT + 1]);
    expect(historyLimits).toEqual([ORDERS_HISTORY_LIMIT + 1]);
    expect(overflowItems).toEqual({
      ok: false,
      message: ORDERS_LOAD_FAILURE_MESSAGE,
    });

    const fromHistoryOverflow = vi.fn((table: string) => {
      if (table === "orders") {
        return {
          select: () => ({
            eq: () => ({
              maybeSingle: async () => ({
                data: buildOrderRow(),
                error: null,
              }),
            }),
          }),
        };
      }

      if (table === "order_items") {
        return {
          select: () => ({
            eq: () => ({
              order: () => ({
                order: () => ({
                  limit: async () => ({
                    data: [buildItemRow("01")],
                    error: null,
                  }),
                }),
              }),
            }),
          }),
        };
      }

      if (table === "order_status_history") {
        return {
          select: () => ({
            eq: () => ({
              order: () => ({
                order: () => ({
                  limit: async (count: number) => {
                    expect(count).toBe(ORDERS_HISTORY_LIMIT + 1);
                    return {
                      data: Array.from(
                        { length: ORDERS_HISTORY_LIMIT + 1 },
                        (_, i) =>
                          buildHistoryRow(String(i).padStart(2, "0").slice(-2)),
                      ),
                      error: null,
                    };
                  },
                }),
              }),
            }),
          }),
        };
      }

      throw new Error(`unexpected table ${table}`);
    });

    const overflowHistory = await getOrderDetail({
      supabase: {
        auth: { getClaims: vi.fn() },
        from: fromHistoryOverflow,
        rpc: vi.fn(),
      } as never,
      orderId: ORDER_ID,
    });

    expect(overflowHistory).toEqual({
      ok: false,
      message: ORDERS_LOAD_FAILURE_MESSAGE,
    });
  });

  it("maps line items with the trusted order currency", async () => {
    authorizeCmsRequest.mockResolvedValue({
      kind: "authorized",
      profile: {
        id: "staff-1",
        fullName: "Staff",
        role: "staff",
        isActive: true,
      },
    });

    const from = vi.fn((table: string) => {
      if (table === "orders") {
        return {
          select: () => ({
            eq: () => ({
              maybeSingle: async () => ({
                data: buildOrderRow(),
                error: null,
              }),
            }),
          }),
        };
      }

      if (table === "order_items") {
        return {
          select: () => ({
            eq: () => ({
              order: () => ({
                order: () => ({
                  limit: async (count: number) => {
                    expect(count).toBe(ORDERS_ITEMS_LIMIT + 1);
                    return {
                      data: [buildItemRow("01")],
                      error: null,
                    };
                  },
                }),
              }),
            }),
          }),
        };
      }

      if (table === "order_status_history") {
        return {
          select: () => ({
            eq: () => ({
              order: () => ({
                order: () => ({
                  limit: async (count: number) => {
                    expect(count).toBe(ORDERS_HISTORY_LIMIT + 1);
                    return {
                      data: [buildHistoryRow("01")],
                      error: null,
                    };
                  },
                }),
              }),
            }),
          }),
        };
      }

      throw new Error(`unexpected table ${table}`);
    });

    const { getOrderDetail } = await import("@/features/orders/queries");
    const result = await getOrderDetail({
      supabase: {
        auth: { getClaims: vi.fn() },
        from,
        rpc: vi.fn(),
      } as never,
      orderId: ORDER_ID,
    });

    expect(result.ok).toBe(true);
    if (!result.ok) {
      return;
    }
    expect(result.detail.currencyCode).toBe("USD");
    expect(result.detail.grandTotalLabel).toMatch(/US\$|USD/);
    expect(result.detail.items[0]?.unitPriceLabel).toMatch(/US\$|USD/);
    expect(result.detail.items[0]?.lineTotalLabel).toMatch(/US\$|USD/);
    expect(result.detail.items[0]?.unitPriceLabel).not.toMatch(/₫|VND/i);
    expect(result.detail.items[0]?.lineTotalLabel).not.toMatch(/₫|VND/i);
  });
});
