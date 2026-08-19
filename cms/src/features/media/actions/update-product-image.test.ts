import { beforeEach, describe, expect, it, vi } from "vitest";

import {
  MEDIA_NOT_FOUND_MESSAGE,
  MEDIA_SUCCESS_UPDATED,
  MEDIA_VARIANT_INVALID_MESSAGE,
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

const rows = [
  {
    id: IMAGE_ID,
    product_id: PRODUCT_ID,
    variant_id: null,
    storage_path: `product-images/${PRODUCT_ID}/a.webp`,
    alt_text: "A",
    sort_order: 0,
    is_primary: true,
    updated_at: "2026-08-19T00:00:00.000Z",
  },
];

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
    const updateEq = vi.fn().mockResolvedValue({ error: null });
    requireMediaActionAuth.mockResolvedValue({
      ok: true,
      supabase: {
        from: (table: string) => {
          if (table === "product_images") {
            return {
              select: () => ({
                eq: () => ({
                  order: () => ({
                    order: () => ({
                      limit: async () => ({ data: rows, error: null }),
                    }),
                  }),
                }),
              }),
              update: (payload: { alt_text: unknown; variant_id: unknown }) => {
                expect(payload.alt_text).toBe("Updated alt");
                expect(payload.variant_id).toBeNull();
                return { eq: () => ({ eq: updateEq }) };
              },
            };
          }
          throw new Error(`unexpected table ${table}`);
        },
        rpc: vi.fn(),
      },
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

    expect(updateEq).toHaveBeenCalled();
    expect(revalidatePath).toHaveBeenCalledWith(productMediaPath(PRODUCT_ID));
  });

  it("rejects a variant that does not belong to the route product", async () => {
    const update = vi.fn();
    requireMediaActionAuth.mockResolvedValue({
      ok: true,
      supabase: {
        from: (table: string) => {
          if (table === "product_images") {
            return {
              select: () => ({
                eq: () => ({
                  order: () => ({
                    order: () => ({
                      limit: async () => ({ data: rows, error: null }),
                    }),
                  }),
                }),
              }),
              update,
            };
          }
          if (table === "product_variants") {
            return {
              select: () => ({
                eq: () => ({
                  maybeSingle: async () => ({
                    data: { id: FOREIGN_VARIANT, product_id: OTHER_PRODUCT },
                    error: null,
                  }),
                }),
              }),
            };
          }
          throw new Error(`unexpected table ${table}`);
        },
        rpc: vi.fn(),
      },
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
    expect(update).not.toHaveBeenCalled();
  });

  it("rejects a forged non-uuid image id before writes", async () => {
    const from = vi.fn();
    requireMediaActionAuth.mockResolvedValue({
      ok: true,
      supabase: { from, rpc: vi.fn() },
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
    expect(from).not.toHaveBeenCalled();
  });
});
