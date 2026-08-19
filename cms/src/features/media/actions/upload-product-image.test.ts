import { beforeEach, describe, expect, it, vi } from "vitest";

import {
  INSERT_CMS_PRODUCT_IMAGE_RPC,
  MEDIA_GENERIC_FAILURE_MESSAGE,
  MEDIA_IMAGE_UPLOAD_FAILURE_MESSAGE,
  MEDIA_PRODUCT_NOT_FOUND_MESSAGE,
  MEDIA_SUCCESS_UPLOADED,
  PRODUCT_IMAGE_LIST_COLUMNS,
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

function productLookupClient(options: {
  upload: ReturnType<typeof vi.fn>;
  remove?: ReturnType<typeof vi.fn>;
  rpc: ReturnType<typeof vi.fn>;
  listed?: unknown[];
}) {
  return {
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
                    limit: async () => ({
                      data: options.listed ?? [],
                      error: null,
                    }),
                  }),
                }),
              }),
            };
          },
          insert: () => {
            throw new Error("direct insert is not allowed");
          },
        };
      }
      throw new Error(`unexpected table ${table}`);
    },
    storage: {
      from: () => ({ upload: options.upload, remove: options.remove }),
    },
    rpc: options.rpc,
  };
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

  it("binds the route product id and inserts through the atomic RPC", async () => {
    const calls: string[] = [];
    const upload = vi.fn().mockImplementation(async () => {
      calls.push("upload");
      return { data: {}, error: null };
    });
    const remove = vi.fn();
    const rpc = vi.fn().mockImplementation(async () => {
      calls.push("rpc");
      return { data: [{ image_id: IMAGE_ID }], error: null };
    });

    requireMediaActionAuth.mockResolvedValue({
      ok: true,
      supabase: productLookupClient({ upload, remove, rpc }),
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
    expect(rpc).toHaveBeenCalledWith(
      INSERT_CMS_PRODUCT_IMAGE_RPC,
      expect.objectContaining({
        p_product_id: PRODUCT_ID,
        p_alt_text: "Main shot",
        p_variant_id: null,
        p_set_primary: false,
      }),
    );
    expect(rpc.mock.calls[0]?.[1]?.p_storage_path).toMatch(
      new RegExp(`^product-images/${PRODUCT_ID}/[0-9a-f-]+\\.png$`),
    );
    expect(calls.indexOf("upload")).toBeLessThan(calls.indexOf("rpc"));
    expect(remove).not.toHaveBeenCalled();
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

  it("deletes the new object if the insert RPC returns an error", async () => {
    const upload = vi.fn().mockResolvedValue({ data: {}, error: null });
    const remove = vi.fn().mockResolvedValue({ data: {}, error: null });
    const rpc = vi.fn().mockResolvedValue({
      data: null,
      error: { message: "duplicate key 23505", code: "23505" },
    });
    requireMediaActionAuth.mockResolvedValue({
      ok: true,
      supabase: productLookupClient({ upload, remove, rpc }),
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
    expect(result.message).toBe(MEDIA_GENERIC_FAILURE_MESSAGE);
    expect(result.message).not.toMatch(/23505|duplicate key|sql/i);
    expect(remove).toHaveBeenCalled();
    expect(redirect).not.toHaveBeenCalled();
  });

  it("deletes the new object if the insert RPC throws", async () => {
    const upload = vi.fn().mockResolvedValue({ data: {}, error: null });
    const remove = vi.fn().mockResolvedValue({ data: {}, error: null });
    const rpc = vi.fn().mockRejectedValue(new Error("rpc exploded"));
    requireMediaActionAuth.mockResolvedValue({
      ok: true,
      supabase: productLookupClient({ upload, remove, rpc }),
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
    expect(result.message).toBe(MEDIA_GENERIC_FAILURE_MESSAGE);
    expect(result.message).not.toMatch(/rpc exploded/i);
    expect(remove).toHaveBeenCalled();
    expect(redirect).not.toHaveBeenCalled();
  });

  it("does not insert a row when storage upload fails", async () => {
    const rpc = vi.fn();
    requireMediaActionAuth.mockResolvedValue({
      ok: true,
      supabase: productLookupClient({
        upload: vi.fn().mockResolvedValue({
          data: null,
          error: { message: "storage boom" },
        }),
        rpc,
      }),
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
    expect(rpc).not.toHaveBeenCalled();
  });
});
