import { beforeEach, describe, expect, it, vi } from "vitest";

import {
  MEDIA_REORDER_INVALID_MESSAGE,
  MEDIA_SUCCESS_REORDERED,
  REORDER_CMS_PRODUCT_IMAGES_RPC,
} from "@/features/media/constants";
import { INITIAL_REORDER_MEDIA_FORM_STATE } from "@/features/media/form-state";

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
const IMAGE_A = "50000000-0000-4000-8000-000000000001";
const IMAGE_B = "50000000-0000-4000-8000-000000000002";
const FORGED = "50000000-0000-4000-8000-000000000088";

const rows = [
  {
    id: IMAGE_A,
    product_id: PRODUCT_ID,
    variant_id: null,
    storage_path: `product-images/${PRODUCT_ID}/a.webp`,
    alt_text: "A",
    sort_order: 0,
    is_primary: true,
    updated_at: "2026-08-19T00:00:00.000Z",
  },
  {
    id: IMAGE_B,
    product_id: PRODUCT_ID,
    variant_id: null,
    storage_path: `product-images/${PRODUCT_ID}/b.webp`,
    alt_text: "B",
    sort_order: 1,
    is_primary: false,
    updated_at: "2026-08-19T00:00:00.000Z",
  },
];

describe("reorderProductImages", () => {
  beforeEach(() => {
    requireMediaActionAuth.mockReset();
    revalidatePath.mockReset();
    redirect.mockReset();
    redirect.mockImplementation((path: string) => {
      throw new Error(`NEXT_REDIRECT:${path}`);
    });
  });

  it("reorders the complete route-bound id list", async () => {
    const rpc = vi.fn().mockResolvedValue({
      data: [{ product_id: PRODUCT_ID }],
      error: null,
    });
    requireMediaActionAuth.mockResolvedValue({
      ok: true,
      supabase: {
        from: () => ({
          select: () => ({
            eq: () => ({
              order: () => ({
                order: () => ({
                  limit: async () => ({ data: rows, error: null }),
                }),
              }),
            }),
          }),
        }),
        rpc,
      },
    });

    const data = new FormData();
    data.append("image_ids", IMAGE_B);
    data.append("image_ids", IMAGE_A);
    data.set("product_id", "30000000-0000-4000-8000-000000000088");

    const { reorderProductImages } = await import(
      "@/features/media/actions/reorder-product-images"
    );
    await expect(
      reorderProductImages(PRODUCT_ID, INITIAL_REORDER_MEDIA_FORM_STATE, data),
    ).rejects.toThrow(`success=${MEDIA_SUCCESS_REORDERED}`);

    expect(rpc).toHaveBeenCalledWith(REORDER_CMS_PRODUCT_IMAGES_RPC, {
      p_product_id: PRODUCT_ID,
      p_image_ids: [IMAGE_B, IMAGE_A],
    });
  });

  it("rejects forged extra ids without calling rpc", async () => {
    const rpc = vi.fn();
    requireMediaActionAuth.mockResolvedValue({
      ok: true,
      supabase: {
        from: () => ({
          select: () => ({
            eq: () => ({
              order: () => ({
                order: () => ({
                  limit: async () => ({ data: rows, error: null }),
                }),
              }),
            }),
          }),
        }),
        rpc,
      },
    });

    const data = new FormData();
    data.append("image_ids", IMAGE_A);
    data.append("image_ids", FORGED);
    const { reorderProductImages } = await import(
      "@/features/media/actions/reorder-product-images"
    );
    const result = await reorderProductImages(
      PRODUCT_ID,
      INITIAL_REORDER_MEDIA_FORM_STATE,
      data,
    );
    expect(result.message).toBe(MEDIA_REORDER_INVALID_MESSAGE);
    expect(rpc).not.toHaveBeenCalled();
  });
});
