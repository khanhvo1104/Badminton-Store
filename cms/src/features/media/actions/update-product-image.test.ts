import { beforeEach, describe, expect, it, vi } from "vitest";

import {
  MEDIA_GENERIC_FAILURE_MESSAGE,
  MEDIA_NOT_FOUND_MESSAGE,
  MEDIA_SUCCESS_UPDATED,
  MEDIA_VARIANT_INVALID_MESSAGE,
  UPDATE_CMS_PRODUCT_IMAGE_RPC,
  productMediaPath,
} from "@/features/media/constants";
import { INITIAL_UPDATE_MEDIA_FORM_STATE } from "@/features/media/form-state";

const requireMediaActionAuth = vi.hoisted(() => vi.fn());
const revalidatePath = vi.hoisted(() => vi.fn());
const redirect = vi.hoisted(() => vi.fn());

vi.mock("@/features/media/action-utils", async () => {
  const actual = await vi.importActual<
    typeof import("@/features/media/action-utils")
  >("@/features/media/action-utils");
  return { ...actual, requireMediaActionAuth };
});
vi.mock("next/cache", () => ({ revalidatePath }));
vi.mock("next/navigation", () => ({ redirect }));

const PRODUCT_ID = "30000000-0000-4000-8000-000000000001";
const IMAGE_ID = "50000000-0000-4000-8000-000000000001";
const FOREIGN_VARIANT = "40000000-0000-4000-8000-000000000088";
const OTHER_PRODUCT = "30000000-0000-4000-8000-000000000088";

describe("updateProductImage", () => {
  beforeEach(() => {
    requireMediaActionAuth.mockReset();
    revalidatePath.mockReset();
    redirect.mockReset();
    redirect.mockImplementation((path: string) => {
      throw new Error(`NEXT_REDIRECT:${path}`);
    });
  });

  it("binds route ids and ignores FormData product_id and image_id", async () => {
    const rpc = vi.fn().mockResolvedValue({
      data: [{ image_id: IMAGE_ID }],
      error: null,
    });
    requireMediaActionAuth.mockResolvedValue({
      ok: true,
      supabase: { from: vi.fn(), rpc },
    });

    const data = new FormData();
    data.set("alt_text", "Updated alt");
    data.set("variant_id", "");
    data.set("sort_order", "3");
    data.set("product_id", OTHER_PRODUCT);
    data.set("image_id", "50000000-0000-4000-8000-000000000099");

    const { updateProductImage } = await import(
      "@/features/media/actions/update-product-image"
    );
    await expect(
      updateProductImage(
        PRODUCT_ID,
        IMAGE_ID,
        INITIAL_UPDATE_MEDIA_FORM_STATE,
        data,
      ),
    ).rejects.toThrow(`success=${MEDIA_SUCCESS_UPDATED}`);

    expect(rpc).toHaveBeenCalledWith(UPDATE_CMS_PRODUCT_IMAGE_RPC, {
      p_product_id: PRODUCT_ID,
      p_image_id: IMAGE_ID,
      p_alt_text: "Updated alt",
      p_variant_id: null,
      p_sort_order: 3,
    });
    expect(revalidatePath).toHaveBeenCalledWith(productMediaPath(PRODUCT_ID));
  });

  it("rejects a variant that does not belong to the route product", async () => {
    const rpc = vi.fn().mockResolvedValue({
      data: null,
      error: { message: "invalid variant", code: "22023" },
    });
    requireMediaActionAuth.mockResolvedValue({
      ok: true,
      supabase: { from: vi.fn(), rpc },
    });

    const data = new FormData();
    data.set("alt_text", "Updated alt");
    data.set("variant_id", FOREIGN_VARIANT);
    data.set("sort_order", "0");

    const { updateProductImage } = await import(
      "@/features/media/actions/update-product-image"
    );
    const result = await updateProductImage(
      PRODUCT_ID,
      IMAGE_ID,
      INITIAL_UPDATE_MEDIA_FORM_STATE,
      data,
    );
    expect(result.message).toBe(MEDIA_VARIANT_INVALID_MESSAGE);
    expect(result.fieldErrors.variantId).toBe(MEDIA_VARIANT_INVALID_MESSAGE);
    expect(redirect).not.toHaveBeenCalled();
  });

  it("rejects a forged non-uuid image id before rpc", async () => {
    const rpc = vi.fn();
    requireMediaActionAuth.mockResolvedValue({
      ok: true,
      supabase: { from: vi.fn(), rpc },
    });
    const { updateProductImage } = await import(
      "@/features/media/actions/update-product-image"
    );
    const result = await updateProductImage(
      PRODUCT_ID,
      "not-a-uuid",
      INITIAL_UPDATE_MEDIA_FORM_STATE,
      new FormData(),
    );
    expect(result.message).toBe(MEDIA_NOT_FOUND_MESSAGE);
    expect(rpc).not.toHaveBeenCalled();
  });

  it("returns a sanitized error when the update RPC throws", async () => {
    const rpc = vi.fn().mockRejectedValue(new Error("partial write boom"));
    requireMediaActionAuth.mockResolvedValue({
      ok: true,
      supabase: { rpc },
    });
    const data = new FormData();
    data.set("alt_text", "Updated alt");
    data.set("sort_order", "0");
    const { updateProductImage } = await import(
      "@/features/media/actions/update-product-image"
    );
    const result = await updateProductImage(
      PRODUCT_ID,
      IMAGE_ID,
      INITIAL_UPDATE_MEDIA_FORM_STATE,
      data,
    );
    expect(result.status).toBe("error");
    expect(result.message).toBe(MEDIA_GENERIC_FAILURE_MESSAGE);
    expect(result.message).not.toMatch(/partial write boom/i);
    expect(redirect).not.toHaveBeenCalled();
  });

  it.each([
    ["empty", []],
    ["protected cost_price", [{ image_id: IMAGE_ID, cost_price: "1" }]],
    ["mismatched", [{ image_id: "50000000-0000-4000-8000-000000000088" }]],
  ])("fail-closes %s RPC payloads", async (_label, payload) => {
    const rpc = vi.fn().mockResolvedValue({ data: payload, error: null });
    requireMediaActionAuth.mockResolvedValue({ ok: true, supabase: { rpc } });
    const data = new FormData();
    data.set("alt_text", "Updated alt");
    data.set("sort_order", "0");
    const { updateProductImage } = await import(
      "@/features/media/actions/update-product-image"
    );
    const result = await updateProductImage(
      PRODUCT_ID,
      IMAGE_ID,
      INITIAL_UPDATE_MEDIA_FORM_STATE,
      data,
    );
    expect(result.message).toBe(MEDIA_GENERIC_FAILURE_MESSAGE);
    expect(redirect).not.toHaveBeenCalled();
  });
});
