import { beforeEach, describe, expect, it, vi } from "vitest";

import {
  MEDIA_IMAGE_CLEANUP_WARNING,
  MEDIA_NOT_FOUND_MESSAGE,
  MEDIA_SUCCESS_REPLACED,
  productMediaPath,
} from "@/features/media/constants";
import { INITIAL_REPLACE_MEDIA_FORM_STATE } from "@/features/media/form-state";

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
const FORGED_IMAGE = "50000000-0000-4000-8000-000000000088";

const existingRow = {
  id: IMAGE_ID,
  product_id: PRODUCT_ID,
  variant_id: null,
  storage_path: `product-images/${PRODUCT_ID}/old.png`,
  alt_text: "Old",
  sort_order: 0,
  is_primary: true,
  updated_at: "2026-08-19T00:00:00.000Z",
};

function pngData(): FormData {
  const data = new FormData();
  data.set(
    "image",
    new File([new Uint8Array([1, 2, 3])], "next.png", { type: "image/png" }),
  );
  data.set("image_id", FORGED_IMAGE);
  data.set("storage_path", "forged/path.png");
  return data;
}

describe("replaceProductImage", () => {
  beforeEach(() => {
    requireMediaActionAuth.mockReset();
    revalidatePath.mockReset();
    redirect.mockReset();
    redirect.mockImplementation((path: string) => {
      throw new Error(`NEXT_REDIRECT:${path}`);
    });
  });

  it("uploads a new object, updates the DB, then removes the old object", async () => {
    const calls: string[] = [];
    const upload = vi.fn().mockImplementation(async () => {
      calls.push("upload");
      return { data: {}, error: null };
    });
    const remove = vi.fn().mockImplementation(async () => {
      calls.push("remove");
      return { data: {}, error: null };
    });
    const updateEq = vi.fn().mockImplementation(async () => {
      calls.push("db-update");
      return { error: null };
    });

    requireMediaActionAuth.mockResolvedValue({
      ok: true,
      supabase: {
        from: () => ({
          select: () => ({
            eq: () => ({
              eq: () => ({
                maybeSingle: async () => ({ data: existingRow, error: null }),
              }),
            }),
          }),
          update: () => ({ eq: () => ({ eq: updateEq }) }),
        }),
        storage: { from: () => ({ upload, remove }) },
      },
    });

    const { replaceProductImage } = await import(
      "@/features/media/actions/replace-product-image"
    );
    await expect(
      replaceProductImage(
        PRODUCT_ID,
        IMAGE_ID,
        INITIAL_REPLACE_MEDIA_FORM_STATE,
        pngData(),
      ),
    ).rejects.toThrow(`success=${MEDIA_SUCCESS_REPLACED}`);

    expect(calls.indexOf("upload")).toBeLessThan(calls.indexOf("db-update"));
    expect(calls.indexOf("db-update")).toBeLessThan(calls.indexOf("remove"));
    expect(remove).toHaveBeenCalledWith([`${PRODUCT_ID}/old.png`]);
    expect(revalidatePath).toHaveBeenCalledWith(productMediaPath(PRODUCT_ID));
  });

  it("deletes the new object and keeps the previous path if the database write fails", async () => {
    const upload = vi.fn().mockResolvedValue({ data: {}, error: null });
    const remove = vi.fn().mockResolvedValue({ data: {}, error: null });
    requireMediaActionAuth.mockResolvedValue({
      ok: true,
      supabase: {
        from: () => ({
          select: () => ({
            eq: () => ({
              eq: () => ({
                maybeSingle: async () => ({ data: existingRow, error: null }),
              }),
            }),
          }),
          update: () => ({
            eq: () => ({
              eq: async () => ({
                error: { message: "permission denied row-level" },
              }),
            }),
          }),
        }),
        storage: { from: () => ({ upload, remove }) },
      },
    });

    const { replaceProductImage } = await import(
      "@/features/media/actions/replace-product-image"
    );
    const result = await replaceProductImage(
      PRODUCT_ID,
      IMAGE_ID,
      INITIAL_REPLACE_MEDIA_FORM_STATE,
      pngData(),
    );
    expect(result.status).toBe("error");
    expect(result.message).not.toMatch(/permission denied|row-level|sql/i);
    expect(remove).toHaveBeenCalled();
    expect(remove.mock.calls[0]?.[0]?.[0]).not.toBe(`${PRODUCT_ID}/old.png`);
  });

  it("returns a cleanup warning when the old object cannot be removed", async () => {
    requireMediaActionAuth.mockResolvedValue({
      ok: true,
      supabase: {
        from: () => ({
          select: () => ({
            eq: () => ({
              eq: () => ({
                maybeSingle: async () => ({ data: existingRow, error: null }),
              }),
            }),
          }),
          update: () => ({ eq: () => ({ eq: async () => ({ error: null }) }) }),
        }),
        storage: {
          from: () => ({
            upload: async () => ({ data: {}, error: null }),
            remove: async () => ({
              data: null,
              error: { message: "storage 500" },
            }),
          }),
        },
      },
    });

    const { replaceProductImage } = await import(
      "@/features/media/actions/replace-product-image"
    );
    const result = await replaceProductImage(
      PRODUCT_ID,
      IMAGE_ID,
      INITIAL_REPLACE_MEDIA_FORM_STATE,
      pngData(),
    );
    expect(result).toMatchObject({
      status: "success",
      message: MEDIA_IMAGE_CLEANUP_WARNING,
    });
    expect(result.message).not.toMatch(/storage 500/i);
  });

  it("rejects a forged non-uuid image id before storage writes", async () => {
    const upload = vi.fn();
    requireMediaActionAuth.mockResolvedValue({
      ok: true,
      supabase: { from: vi.fn(), storage: { from: () => ({ upload }) } },
    });
    const { replaceProductImage } = await import(
      "@/features/media/actions/replace-product-image"
    );
    const result = await replaceProductImage(
      PRODUCT_ID,
      "not-a-uuid",
      INITIAL_REPLACE_MEDIA_FORM_STATE,
      pngData(),
    );
    expect(result.message).toBe(MEDIA_NOT_FOUND_MESSAGE);
    expect(upload).not.toHaveBeenCalled();
  });
});
