import { beforeEach, describe, expect, it, vi } from "vitest";

import {
  VARIANT_AUTH_DENIED_MESSAGE,
  VARIANT_LOAD_FAILURE_MESSAGE,
  VARIANT_SAFE_COLUMNS,
} from "@/features/variants/constants";

const authorizeCmsRequest = vi.hoisted(() => vi.fn());
const getProductById = vi.hoisted(() => vi.fn());

vi.mock("@/lib/auth/authorization", async () => {
  const actual = await vi.importActual<
    typeof import("@/lib/auth/authorization")
  >("@/lib/auth/authorization");
  return { ...actual, authorizeCmsRequest };
});

vi.mock("@/features/products/detail-queries", async () => {
  const actual = await vi.importActual<
    typeof import("@/features/products/detail-queries")
  >("@/features/products/detail-queries");
  return { ...actual, getProductById };
});

const PRODUCT_ID = "30000000-0000-4000-8000-000000000001";
const VARIANT_ID = "40000000-0000-4000-8000-000000000001";

const SAFE_ROW = {
  id: VARIANT_ID,
  product_id: PRODUCT_ID,
  sku: "SKU-1",
  name: "Name",
  color_name: null,
  color_hex: null,
  racket_weight_class: null,
  grip_size: null,
  shoe_size: null,
  clothing_size: null,
  unit: "item",
  price: "10.00",
  compare_at_price: null,
  attributes: {},
  is_default: true,
  is_active: true,
  sort_order: 0,
};

describe("listProductVariants", () => {
  beforeEach(() => {
    authorizeCmsRequest.mockReset();
    getProductById.mockReset();
  });

  it("authorizes before reading variants or costs", async () => {
    const from = vi.fn();
    const rpc = vi.fn();
    authorizeCmsRequest.mockResolvedValue({ kind: "unauthorized" });

    const { listProductVariants } = await import("@/features/variants/queries");
    const result = await listProductVariants({
      supabase: { auth: { getClaims: vi.fn() }, from, rpc } as never,
      productId: PRODUCT_ID,
    });

    expect(result).toEqual({
      ok: false,
      message: VARIANT_AUTH_DENIED_MESSAGE,
    });
    expect(from).not.toHaveBeenCalled();
    expect(rpc).not.toHaveBeenCalled();
    expect(getProductById).not.toHaveBeenCalled();
  });

  it("selects explicit safe columns and merges costs", async () => {
    authorizeCmsRequest.mockResolvedValue({
      kind: "authorized",
      profile: {
        id: "staff-1",
        fullName: "Staff",
        role: "staff",
        isActive: true,
      },
    });
    getProductById.mockResolvedValue({
      ok: true,
      product: { id: PRODUCT_ID, name: "Aero Strike" },
    });

    const limit = vi.fn().mockResolvedValue({ data: [SAFE_ROW], error: null });
    const orderId = vi.fn(() => ({ limit }));
    const orderSort = vi.fn(() => ({ order: orderId }));
    const eq = vi.fn(() => ({ order: orderSort }));
    const select = vi.fn(() => ({ eq }));
    const from = vi.fn(() => ({ select }));
    const rpc = vi.fn().mockResolvedValue({
      data: [{ variant_id: VARIANT_ID, cost_price: null }],
      error: null,
    });

    const { listProductVariants } = await import("@/features/variants/queries");
    const result = await listProductVariants({
      supabase: { auth: { getClaims: vi.fn() }, from, rpc } as never,
      productId: PRODUCT_ID,
    });

    expect(select).toHaveBeenCalledWith(VARIANT_SAFE_COLUMNS);
    expect(JSON.stringify(select.mock.calls)).not.toMatch(
      /cost_price|barcode|\*/,
    );
    expect(rpc).toHaveBeenCalledWith("get_staff_variant_costs", {
      p_product_id: PRODUCT_ID,
    });
    expect(result.ok).toBe(true);
    if (result.ok) {
      expect(result.data.variants).toHaveLength(1);
      expect(result.data.variants[0]?.costPrice).toBeNull();
      expect(result.data.productName).toBe("Aero Strike");
    }
  });

  it("fails closed on malformed variant rows", async () => {
    authorizeCmsRequest.mockResolvedValue({
      kind: "authorized",
      profile: {
        id: "staff-1",
        fullName: "Staff",
        role: "staff",
        isActive: true,
      },
    });
    getProductById.mockResolvedValue({
      ok: true,
      product: { id: PRODUCT_ID, name: "Aero Strike" },
    });
    const limit = vi.fn().mockResolvedValue({
      data: [{ ...SAFE_ROW, cost_price: "1" }],
      error: null,
    });
    const from = vi.fn(() => ({
      select: vi.fn(() => ({
        eq: vi.fn(() => ({
          order: vi.fn(() => ({
            order: vi.fn(() => ({ limit })),
          })),
        })),
      })),
    }));
    const rpc = vi.fn();

    const { listProductVariants } = await import("@/features/variants/queries");
    const result = await listProductVariants({
      supabase: { auth: { getClaims: vi.fn() }, from, rpc } as never,
      productId: PRODUCT_ID,
    });
    expect(result).toEqual({
      ok: false,
      message: VARIANT_LOAD_FAILURE_MESSAGE,
    });
    expect(rpc).not.toHaveBeenCalled();
  });
});
