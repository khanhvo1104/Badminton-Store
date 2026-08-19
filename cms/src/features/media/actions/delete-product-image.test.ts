import { beforeEach, describe, expect, it, vi } from "vitest";

import {
  MEDIA_DELETE_CLEANUP_WARNING,
  MEDIA_DELETE_CONFIRM_REQUIRED_MESSAGE,
  MEDIA_SUCCESS_DELETED,
  SET_CMS_PRODUCT_IMAGE_PRIMARY_RPC,
  productMediaPath,
} from "@/features/media/constants";
import { INITIAL_DELETE_MEDIA_FORM_STATE } from "@/features/media/form-state";

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

describe("deleteProductImage", () => {
  beforeEach(() => {
    requireMediaActionAuth.mockReset();
    revalidatePath.mockReset();
    redirect.mockReset();
    redirect.mockImplementation((path: string) => {
      throw new Error(`NEXT_REDIRECT:${path}`);
    });
  });

  it("requires confirmation before authorizing or writing", async () => {
    const { deleteProductImage } = await import(
      "@/features/media/actions/delete-product-image"
    );
    const result = await deleteProductImage(
      PRODUCT_ID,
      IMAGE_A,
      INITIAL_DELETE_MEDIA_FORM_STATE,
      new FormData(),
    );
    expect(result.message).toBe(MEDIA_DELETE_CONFIRM_REQUIRED_MESSAGE);
    expect(requireMediaActionAuth).not.toHaveBeenCalled();
  });

  it("deletes the database row before storage and promotes the next primary", async () => {
    const calls: string[] = [];
    const remove = vi.fn().mockImplementation(async () => {
      calls.push("remove");
      return { data: {}, error: null };
    });
    const delEq = vi.fn().mockImplementation(async () => {
      calls.push("db-delete");
      return { error: null };
    });
    const rpc = vi.fn().mockImplementation(async () => {
      calls.push("rpc");
      return { data: [{ image_id: IMAGE_B }], error: null };
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
          delete: () => ({ eq: () => ({ eq: delEq }) }),
        }),
        storage: { from: () => ({ remove }) },
        rpc,
      },
    });

    const data = new FormData();
    data.set("confirmed", "yes");
    data.set("image_id", "forged");
    const { deleteProductImage } = await import(
      "@/features/media/actions/delete-product-image"
    );
    await expect(
      deleteProductImage(
        PRODUCT_ID,
        IMAGE_A,
        INITIAL_DELETE_MEDIA_FORM_STATE,
        data,
      ),
    ).rejects.toThrow(`success=${MEDIA_SUCCESS_DELETED}`);

    expect(calls.indexOf("rpc")).toBeLessThan(calls.indexOf("db-delete"));
    expect(calls.indexOf("db-delete")).toBeLessThan(calls.indexOf("remove"));
    expect(rpc).toHaveBeenCalledWith(SET_CMS_PRODUCT_IMAGE_PRIMARY_RPC, {
      p_product_id: PRODUCT_ID,
      p_image_id: IMAGE_B,
    });
    expect(remove).toHaveBeenCalledWith([`${PRODUCT_ID}/a.webp`]);
    expect(revalidatePath).toHaveBeenCalledWith(productMediaPath(PRODUCT_ID));
  });

  it("keeps the database change and warns when storage cleanup fails", async () => {
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
          delete: () => ({ eq: () => ({ eq: async () => ({ error: null }) }) }),
        }),
        storage: {
          from: () => ({
            remove: async () => ({
              data: null,
              error: { message: "NoSuchKey at s3://internal" },
            }),
          }),
        },
        rpc: async () => ({ data: [{ image_id: IMAGE_B }], error: null }),
      },
    });

    const data = new FormData();
    data.set("confirmed", "yes");
    const { deleteProductImage } = await import(
      "@/features/media/actions/delete-product-image"
    );
    const result = await deleteProductImage(
      PRODUCT_ID,
      IMAGE_A,
      INITIAL_DELETE_MEDIA_FORM_STATE,
      data,
    );
    expect(result).toMatchObject({
      status: "success",
      message: MEDIA_DELETE_CLEANUP_WARNING,
    });
    expect(result.message).not.toMatch(/NoSuchKey|s3:\/\//i);
  });
});
