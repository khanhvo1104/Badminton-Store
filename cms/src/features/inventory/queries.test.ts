import { beforeEach, describe, expect, it, vi } from "vitest";

import {
  INVENTORY_AUTH_DENIED_MESSAGE,
  INVENTORY_VARIANT_COLUMNS,
  LIST_CMS_INVENTORY_RPC,
} from "@/features/inventory/constants";

const authorizeCmsRequest = vi.hoisted(() => vi.fn());

vi.mock("@/lib/auth/authorization", async () => {
  const actual = await vi.importActual<
    typeof import("@/lib/auth/authorization")
  >("@/lib/auth/authorization");
  return { ...actual, authorizeCmsRequest };
});

const VARIANT_ID = "40000000-0000-4000-8000-000000000001";
const PRODUCT_ID = "30000000-0000-4000-8000-000000000001";

describe("listInventory", () => {
  beforeEach(() => {
    authorizeCmsRequest.mockReset();
  });

  it("authorizes before reading inventory", async () => {
    const from = vi.fn();
    const rpc = vi.fn();
    authorizeCmsRequest.mockResolvedValue({ kind: "unauthorized" });

    const { listInventory } = await import("@/features/inventory/queries");
    const result = await listInventory({
      supabase: { auth: { getClaims: vi.fn() }, from, rpc } as never,
      query: {
        search: "",
        stock: "all",
        sort: "updated_desc",
        pagination: { page: 1, pageSize: 20, from: 0, to: 19 },
      },
    });

    expect(result).toEqual({
      ok: false,
      message: INVENTORY_AUTH_DENIED_MESSAGE,
    });
    expect(from).not.toHaveBeenCalled();
    expect(rpc).not.toHaveBeenCalled();
  });

  it("calls the list RPC with bounded args", async () => {
    authorizeCmsRequest.mockResolvedValue({
      kind: "authorized",
      profile: {
        id: "staff-1",
        fullName: "Staff",
        role: "staff",
        isActive: true,
      },
    });
    const rpc = vi.fn().mockResolvedValue({
      data: [
        {
          variant_id: VARIANT_ID,
          product_id: PRODUCT_ID,
          product_name: "Aero",
          variant_name: "Red",
          sku: "SKU-1",
          quantity_on_hand: 10,
          quantity_reserved: 1,
          quantity_available: 9,
          reorder_level: 2,
          allow_backorder: false,
          stock_state: "in_stock",
          updated_at: "2026-08-18T00:00:00.000Z",
          filtered_count: 1,
        },
      ],
      error: null,
    });

    const { listInventory } = await import("@/features/inventory/queries");
    const result = await listInventory({
      supabase: {
        auth: { getClaims: vi.fn() },
        from: vi.fn(),
        rpc,
      } as never,
      query: {
        search: "SKU",
        stock: "in_stock",
        sort: "sku_asc",
        pagination: { page: 1, pageSize: 20, from: 0, to: 19 },
      },
    });

    expect(rpc).toHaveBeenCalledWith(LIST_CMS_INVENTORY_RPC, {
      p_search: "SKU",
      p_stock: "in_stock",
      p_sort: "sku_asc",
      p_offset: 0,
      p_limit: 20,
    });
    expect(result.ok).toBe(true);
    if (result.ok) {
      expect(result.result.items[0]?.sku).toBe("SKU-1");
    }
  });
});

describe("getInventoryVariant", () => {
  beforeEach(() => {
    authorizeCmsRequest.mockReset();
  });

  it("authorizes before reading variant inventory", async () => {
    const from = vi.fn();
    const rpc = vi.fn();
    authorizeCmsRequest.mockResolvedValue({ kind: "anonymous" });

    const { getInventoryVariant } = await import(
      "@/features/inventory/queries"
    );
    const result = await getInventoryVariant({
      supabase: { auth: { getClaims: vi.fn() }, from, rpc } as never,
      variantId: VARIANT_ID,
    });

    expect(result).toEqual({
      ok: false,
      message: INVENTORY_AUTH_DENIED_MESSAGE,
    });
    expect(from).not.toHaveBeenCalled();
    expect(rpc).not.toHaveBeenCalled();
  });

  it("selects explicit variant columns without cost or barcode", async () => {
    authorizeCmsRequest.mockResolvedValue({
      kind: "authorized",
      profile: {
        id: "staff-1",
        fullName: "Staff",
        role: "staff",
        isActive: true,
      },
    });

    const maybeSingle = vi.fn().mockResolvedValue({
      data: {
        id: VARIANT_ID,
        product_id: PRODUCT_ID,
        sku: "SKU-1",
        name: "Red",
      },
      error: null,
    });
    const select = vi.fn().mockReturnValue({
      eq: vi.fn().mockReturnValue({
        maybeSingle,
        order: vi.fn().mockReturnValue({
          order: vi.fn().mockReturnValue({
            limit: vi.fn().mockResolvedValue({ data: [], error: null }),
          }),
        }),
      }),
      in: vi.fn().mockReturnValue({
        limit: vi.fn().mockResolvedValue({ data: [], error: null }),
      }),
    });
    const from = vi.fn().mockReturnValue({ select });

    const { getInventoryVariant } = await import(
      "@/features/inventory/queries"
    );
    await getInventoryVariant({
      supabase: {
        auth: { getClaims: vi.fn() },
        from,
        rpc: vi.fn(),
      } as never,
      variantId: VARIANT_ID,
    });

    expect(select).toHaveBeenCalledWith(INVENTORY_VARIANT_COLUMNS);
    expect(INVENTORY_VARIANT_COLUMNS).not.toMatch(/cost_price|barcode/);
  });
});
