import { beforeEach, describe, expect, it, vi } from "vitest";

import {
  MEDIA_IMAGE_UPLOAD_FAILURE_MESSAGE,
  MEDIA_PRODUCT_NOT_FOUND_MESSAGE,
  MEDIA_SUCCESS_UPLOADED,
  PRODUCT_IMAGE_LIST_COLUMNS,
  SET_CMS_PRODUCT_IMAGE_PRIMARY_RPC,
  productMediaPath,
} from "@/features/media/constants";
import { INITIAL_UPLOAD_MEDIA_FORM_STATE } from "@/features/media/form-state";

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
const IMAGE_ID = "50000000-0000-4000-8000-000000000099";
const FORGED_PRODUCT = "30000000-0000-4000-8000-000000000088";

function pngData(overrides: Record<string, string> = {}): FormData {
  const data = new FormData();
  data.set(
    "image",
    new File([new Uint8Array([1, 2, 3])], "shot.png", { type: "image/png" }),
  );
  data.set("alt_text", overrides.alt_text ?? "Main shot");
  data.set("variant_id", overrides.variant_id ?? "");
  data.set("product_id", overrides.product_id ?? FORGED_PRODUCT);
  if (overrides.set_primary) {
    data.set("set_primary", overrides.set_primary);
  }
  return data;
}

describe("uploadProductImage", () => {
  beforeEach(() => {
    requireMediaActionAuth.mockReset();
    revalidatePath.mockReset();
    redirect.mockReset();
    redirect.mockImplementation((path: string) => {
      throw new Error(`NEXT_REDIRECT:${path}`);
    });
  });

  it("binds the route product id and ignores FormData product_id", async () => {
    const calls: string[] = [];
    const upload = vi.fn().mockImplementation(async () => {
      calls.push("upload");
      return { data: {}, error: null };
    });
    const remove = vi.fn();
    const insertMaybeSingle = vi.fn().mockImplementation(async () => {
      calls.push("insert");
      return { data: { id: IMAGE_ID }, error: null };
    });
    const rpc = vi.fn().mockImplementation(async () => {
      calls.push("rpc");
      return { data: [{ image_id: IMAGE_ID }], error: null };
    });

    requireMediaActionAuth.mockResolvedValue({
      ok: true,
      supabase: {
        from: (table: string) => {
          if (table === "products") {
            return {
              select: () => ({
                eq: () => ({
                  maybeSingle: async () => ({
                    data: { id: PRODUCT_ID },
                    error: null,
                  }),
                }),
              }),
            };
          }
          if (table === "product_images") {
            return {
              select: (columns: string) => {
                expect(columns).toBe(PRODUCT_IMAGE_LIST_COLUMNS);
                return {
                  eq: () => ({
                    order: () => ({
                      order: () => ({
                        limit: async () => ({ data: [], error: null }),
                      }),
                    }),
                  }),
                };
              },
              insert: () => ({
                select: () => ({ maybeSingle: insertMaybeSingle }),
              }),
            };
          }
          throw new Error(`unexpected table ${table}`);
        },
        storage: { from: () => ({ upload, remove }) },
        rpc,
      },
    });

    const { uploadProductImage } = await import(
      "@/features/media/actions/upload-product-image"
    );
    await expect(
      uploadProductImage(
        PRODUCT_ID,
        INITIAL_UPLOAD_MEDIA_FORM_STATE,
        pngData(),
      ),
    ).rejects.toThrow(`success=${MEDIA_SUCCESS_UPLOADED}`);

    expect(upload.mock.calls[0]?.[0]).toMatch(
      new RegExp(`^${PRODUCT_ID}/[0-9a-f-]+\\.png$`),
    );
    expect(upload.mock.calls[0]?.[2]).toMatchObject({ upsert: false });
    expect(rpc).toHaveBeenCalledWith(SET_CMS_PRODUCT_IMAGE_PRIMARY_RPC, {
      p_product_id: PRODUCT_ID,
      p_image_id: IMAGE_ID,
    });
    expect(calls.indexOf("upload")).toBeLessThan(calls.indexOf("insert"));
    expect(revalidatePath).toHaveBeenCalledWith(productMediaPath(PRODUCT_ID));
  });

  it("rejects a forged non-uuid route id before storage writes", async () => {
    const upload = vi.fn();
    requireMediaActionAuth.mockResolvedValue({
      ok: true,
      supabase: { from: vi.fn(), storage: { from: () => ({ upload }) } },
    });
    const { uploadProductImage } = await import(
      "@/features/media/actions/upload-product-image"
    );
    const result = await uploadProductImage(
      "not-a-uuid",
      INITIAL_UPLOAD_MEDIA_FORM_STATE,
      pngData(),
    );
    expect(result.message).toBe(MEDIA_PRODUCT_NOT_FOUND_MESSAGE);
    expect(upload).not.toHaveBeenCalled();
  });

  it("deletes the new object if the database insert fails", async () => {
    const upload = vi.fn().mockResolvedValue({ data: {}, error: null });
    const remove = vi.fn().mockResolvedValue({ data: {}, error: null });
    requireMediaActionAuth.mockResolvedValue({
      ok: true,
      supabase: {
        from: (table: string) => {
          if (table === "products") {
            return {
              select: () => ({
                eq: () => ({
                  maybeSingle: async () => ({
                    data: { id: PRODUCT_ID },
                    error: null,
                  }),
                }),
              }),
            };
          }
          return {
            select: () => ({
              eq: () => ({
                order: () => ({
                  order: () => ({
                    limit: async () => ({ data: [], error: null }),
                  }),
                }),
              }),
            }),
            insert: () => ({
              select: () => ({
                maybeSingle: async () => ({
                  data: null,
                  error: { message: "duplicate key 23505" },
                }),
              }),
            }),
          };
        },
        storage: { from: () => ({ upload, remove }) },
        rpc: vi.fn(),
      },
    });

    const { uploadProductImage } = await import(
      "@/features/media/actions/upload-product-image"
    );
    const result = await uploadProductImage(
      PRODUCT_ID,
      INITIAL_UPLOAD_MEDIA_FORM_STATE,
      pngData(),
    );
    expect(result.status).toBe("error");
    expect(result.message).not.toMatch(/23505|duplicate key|sql/i);
    expect(remove).toHaveBeenCalled();
  });

  it("does not insert a row when storage upload fails", async () => {
    const insert = vi.fn();
    requireMediaActionAuth.mockResolvedValue({
      ok: true,
      supabase: {
        from: (table: string) => {
          if (table === "products") {
            return {
              select: () => ({
                eq: () => ({
                  maybeSingle: async () => ({
                    data: { id: PRODUCT_ID },
                    error: null,
                  }),
                }),
              }),
            };
          }
          return {
            select: () => ({
              eq: () => ({
                order: () => ({
                  order: () => ({
                    limit: async () => ({ data: [], error: null }),
                  }),
                }),
              }),
            }),
            insert,
          };
        },
        storage: {
          from: () => ({
            upload: async () => ({
              data: null,
              error: { message: "storage boom" },
            }),
          }),
        },
        rpc: vi.fn(),
      },
    });
    const { uploadProductImage } = await import(
      "@/features/media/actions/upload-product-image"
    );
    const result = await uploadProductImage(
      PRODUCT_ID,
      INITIAL_UPLOAD_MEDIA_FORM_STATE,
      pngData(),
    );
    expect(result.message).toBe(MEDIA_IMAGE_UPLOAD_FAILURE_MESSAGE);
    expect(insert).not.toHaveBeenCalled();
  });
});
