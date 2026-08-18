import { beforeEach, describe, expect, it, vi } from "vitest";

import { INITIAL_VARIANT_FORM_STATE } from "@/features/variants/variant-form-state";
import {
  VARIANT_AUTH_DENIED_MESSAGE,
  VARIANT_BOOLEAN_INVALID_MESSAGE,
  VARIANT_NOT_FOUND_MESSAGE,
  VARIANT_PRODUCT_NOT_FOUND_MESSAGE,
  VARIANT_SKU_CONFLICT_MESSAGE,
} from "@/features/variants/constants";

const requireVariantActionAuth = vi.hoisted(() => vi.fn());
const revalidatePath = vi.hoisted(() => vi.fn());
const redirect = vi.hoisted(() => vi.fn());

vi.mock("@/features/variants/action-utils", async () => {
  const actual = await vi.importActual<
    typeof import("@/features/variants/action-utils")
  >("@/features/variants/action-utils");
  return { ...actual, requireVariantActionAuth };
});

vi.mock("next/cache", () => ({ revalidatePath }));
vi.mock("next/navigation", () => ({ redirect }));

const PRODUCT_ID = "30000000-0000-4000-8000-000000000001";
const VARIANT_ID = "40000000-0000-4000-8000-000000000001";
const FORGED_PRODUCT_ID = "30000000-0000-4000-8000-000000000088";
const FORGED_VARIANT_ID = "40000000-0000-4000-8000-000000000088";

const SAFE_ROW = {
  id: VARIANT_ID,
  product_id: PRODUCT_ID,
  sku: "SKU-1",
  name: null,
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
  is_default: false,
  is_active: true,
  sort_order: 0,
};

function validFormData(overrides: Record<string, string> = {}): FormData {
  const data = new FormData();
  data.set("sku", overrides.sku ?? "SKU-1");
  data.set("name", overrides.name ?? "");
  data.set("color_name", "");
  data.set("color_hex", "");
  data.set("racket_weight_class", "");
  data.set("grip_size", "");
  data.set("shoe_size", "");
  data.set("clothing_size", "");
  data.set("unit", "item");
  data.set("price", overrides.price ?? "10.00");
  data.set("compare_at_price", overrides.compare_at_price ?? "");
  data.set("cost_price", overrides.cost_price ?? "");
  data.set("barcode", overrides.barcode ?? "");
  data.set("attributes", overrides.attributes ?? "");
  data.set("is_default", overrides.is_default ?? "false");
  data.set("is_active", overrides.is_active ?? "true");
  data.set("sort_order", overrides.sort_order ?? "0");
  return data;
}

describe("createVariant", () => {
  beforeEach(() => {
    requireVariantActionAuth.mockReset();
    revalidatePath.mockReset();
    redirect.mockReset();
  });

  it("denies unauthorized callers before any write", async () => {
    const rpc = vi.fn();
    requireVariantActionAuth.mockResolvedValue({
      ok: false,
      state: {
        status: "error",
        message: VARIANT_AUTH_DENIED_MESSAGE,
        fieldErrors: {},
        values: INITIAL_VARIANT_FORM_STATE.values,
      },
    });

    const { createVariant } = await import(
      "@/features/variants/actions/create-variant"
    );
    const result = await createVariant(
      PRODUCT_ID,
      INITIAL_VARIANT_FORM_STATE,
      validFormData(),
    );
    expect(result.message).toBe(VARIANT_AUTH_DENIED_MESSAGE);
    expect(rpc).not.toHaveBeenCalled();
  });

  it("rejects an invalid bound product id before writing", async () => {
    const rpc = vi.fn();
    requireVariantActionAuth.mockResolvedValue({
      ok: true,
      supabase: { rpc, from: vi.fn() },
    });
    const { createVariant } = await import(
      "@/features/variants/actions/create-variant"
    );
    const result = await createVariant(
      "not-a-uuid",
      INITIAL_VARIANT_FORM_STATE,
      validFormData(),
    );
    expect(result.message).toBe(VARIANT_PRODUCT_NOT_FOUND_MESSAGE);
    expect(rpc).not.toHaveBeenCalled();
  });

  it("creates a variant with bound product id and ignore forged form ids", async () => {
    const rpc = vi.fn().mockResolvedValue({
      data: [{ variant_id: VARIANT_ID }],
      error: null,
    });
    requireVariantActionAuth.mockResolvedValue({
      ok: true,
      supabase: { rpc, from: vi.fn() },
    });
    redirect.mockImplementation(() => {
      throw new Error("NEXT_REDIRECT");
    });

    const { createVariant } = await import(
      "@/features/variants/actions/create-variant"
    );
    const formData = validFormData({ barcode: "ABC" });
    formData.set("product_id", FORGED_PRODUCT_ID);
    formData.set("variant_id", FORGED_VARIANT_ID);

    await expect(
      createVariant(PRODUCT_ID, INITIAL_VARIANT_FORM_STATE, formData),
    ).rejects.toThrow("NEXT_REDIRECT");

    expect(rpc).toHaveBeenCalledWith(
      "save_cms_product_variant",
      expect.objectContaining({
        p_product_id: PRODUCT_ID,
        p_variant_id: null,
        p_barcode_mode: "set",
        p_barcode: "ABC",
      }),
    );
    expect(rpc.mock.calls[0]?.[1].p_product_id).not.toBe(FORGED_PRODUCT_ID);
    expect(revalidatePath).toHaveBeenCalledWith(
      `/dashboard/products/${PRODUCT_ID}/variants`,
    );
  });

  it("maps duplicate SKU to a field error", async () => {
    const rpc = vi.fn().mockResolvedValue({
      error: {
        code: "23505",
        message:
          'duplicate key value violates unique constraint "product_variants_sku_unique"',
      },
    });
    requireVariantActionAuth.mockResolvedValue({
      ok: true,
      supabase: { rpc, from: vi.fn() },
    });
    const { createVariant } = await import(
      "@/features/variants/actions/create-variant"
    );
    const result = await createVariant(
      PRODUCT_ID,
      INITIAL_VARIANT_FORM_STATE,
      validFormData(),
    );
    expect(result.fieldErrors.sku).toBe(VARIANT_SKU_CONFLICT_MESSAGE);
  });

  it("rejects missing booleans without writing", async () => {
    const rpc = vi.fn();
    requireVariantActionAuth.mockResolvedValue({
      ok: true,
      supabase: { rpc, from: vi.fn() },
    });
    const { createVariant } = await import(
      "@/features/variants/actions/create-variant"
    );
    const formData = validFormData();
    formData.delete("is_default");
    const result = await createVariant(
      PRODUCT_ID,
      INITIAL_VARIANT_FORM_STATE,
      formData,
    );
    expect(result.fieldErrors.isDefault).toBe(VARIANT_BOOLEAN_INVALID_MESSAGE);
    expect(rpc).not.toHaveBeenCalled();
  });
});

describe("updateVariant", () => {
  beforeEach(() => {
    requireVariantActionAuth.mockReset();
    revalidatePath.mockReset();
    redirect.mockReset();
  });

  function mockUpdateClient(options: {
    rpc?: ReturnType<typeof vi.fn>;
    row?: typeof SAFE_ROW | null;
  }) {
    const rpc = options.rpc ?? vi.fn();
    const eqProduct = vi.fn(() => ({
      maybeSingle: vi.fn().mockResolvedValue({
        data: options.row === undefined ? SAFE_ROW : options.row,
        error: null,
      }),
    }));
    const eqId = vi.fn(() => ({ eq: eqProduct }));
    requireVariantActionAuth.mockResolvedValue({
      ok: true,
      supabase: {
        rpc,
        from: vi.fn(() => ({
          select: vi.fn(() => ({ eq: eqId })),
        })),
      },
    });
    return { rpc, eqId, eqProduct };
  }

  it("uses bound route ids and ignores forged form ids", async () => {
    const { rpc, eqId, eqProduct } = mockUpdateClient({
      rpc: vi.fn().mockResolvedValue({
        data: [{ variant_id: VARIANT_ID }],
        error: null,
      }),
    });
    redirect.mockImplementation(() => {
      throw new Error("NEXT_REDIRECT");
    });
    const { updateVariant } = await import(
      "@/features/variants/actions/update-variant"
    );
    const formData = validFormData();
    formData.set("product_id", FORGED_PRODUCT_ID);
    formData.set("variant_id", FORGED_VARIANT_ID);

    await expect(
      updateVariant(
        PRODUCT_ID,
        VARIANT_ID,
        INITIAL_VARIANT_FORM_STATE,
        formData,
      ),
    ).rejects.toThrow("NEXT_REDIRECT");

    expect(eqId).toHaveBeenCalledWith("id", VARIANT_ID);
    expect(eqProduct).toHaveBeenCalledWith("product_id", PRODUCT_ID);
    expect(rpc).toHaveBeenCalledWith(
      "save_cms_product_variant",
      expect.objectContaining({
        p_product_id: PRODUCT_ID,
        p_variant_id: VARIANT_ID,
        p_barcode_mode: "unchanged",
        p_cost_mode: "clear",
      }),
    );
    expect(rpc.mock.calls[0]?.[1].p_variant_id).not.toBe(FORGED_VARIANT_ID);
  });

  it("returns not found for an invalid bound variant id before writing", async () => {
    const rpc = vi.fn();
    requireVariantActionAuth.mockResolvedValue({
      ok: true,
      supabase: { rpc, from: vi.fn() },
    });
    const { updateVariant } = await import(
      "@/features/variants/actions/update-variant"
    );
    const result = await updateVariant(
      PRODUCT_ID,
      "not-a-uuid",
      INITIAL_VARIANT_FORM_STATE,
      validFormData(),
    );
    expect(result.message).toBe(VARIANT_NOT_FOUND_MESSAGE);
    expect(rpc).not.toHaveBeenCalled();
  });

  it("returns not found when the bound variant row is missing", async () => {
    const { rpc } = mockUpdateClient({ row: null });
    const { updateVariant } = await import(
      "@/features/variants/actions/update-variant"
    );
    const result = await updateVariant(
      PRODUCT_ID,
      VARIANT_ID,
      INITIAL_VARIANT_FORM_STATE,
      validFormData(),
    );
    expect(result.message).toBe(VARIANT_NOT_FOUND_MESSAGE);
    expect(rpc).not.toHaveBeenCalled();
  });
});
