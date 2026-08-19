import { beforeEach, describe, expect, it, vi } from "vitest";

import { INITIAL_UPLOAD_MEDIA_FORM_STATE } from "@/features/media/form-state";
import { INITIAL_REPLACE_MEDIA_FORM_STATE } from "@/features/media/form-state";
import { INITIAL_DELETE_MEDIA_FORM_STATE } from "@/features/media/form-state";
import { INITIAL_PRIMARY_MEDIA_FORM_STATE } from "@/features/media/form-state";
import { INITIAL_UPDATE_MEDIA_FORM_STATE } from "@/features/media/form-state";
import { INITIAL_REORDER_MEDIA_FORM_STATE } from "@/features/media/form-state";
import { MEDIA_AUTH_DENIED_MESSAGE } from "@/features/media/constants";

const createSupabaseServerClient = vi.hoisted(() => vi.fn());
const authorizeCmsRequest = vi.hoisted(() => vi.fn());

vi.mock("@/lib/supabase/server", () => ({ createSupabaseServerClient }));
vi.mock("@/lib/auth/authorization", async () => {
  const actual = await vi.importActual<
    typeof import("@/lib/auth/authorization")
  >("@/lib/auth/authorization");
  return { ...actual, authorizeCmsRequest };
});

const PRODUCT_ID = "30000000-0000-4000-8000-000000000001";
const IMAGE_ID = "50000000-0000-4000-8000-000000000001";

function pngFile(): File {
  return new File([new Uint8Array([1, 2, 3])], "shot.png", {
    type: "image/png",
  });
}

describe("media server actions auth", () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it.each([
    ["anonymous", { kind: "anonymous" }],
    ["customer", { kind: "unauthorized" }],
    ["inactive", { kind: "unauthorized" }],
    ["malformed", { kind: "unauthorized" }],
    ["recovery", { kind: "unauthorized" }],
  ] as const)(
    "denies %s upload without writing",
    async (_label, authorization) => {
      const from = vi.fn();
      const upload = vi.fn();
      const rpc = vi.fn();
      authorizeCmsRequest.mockResolvedValue(authorization);
      createSupabaseServerClient.mockResolvedValue({
        from,
        rpc,
        storage: { from: () => ({ upload }) },
      });

      const data = new FormData();
      data.set("image", pngFile());
      const { uploadProductImage } = await import(
        "@/features/media/actions/upload-product-image"
      );
      await expect(
        uploadProductImage(PRODUCT_ID, INITIAL_UPLOAD_MEDIA_FORM_STATE, data),
      ).resolves.toMatchObject({
        status: "error",
        message: MEDIA_AUTH_DENIED_MESSAGE,
      });
      expect(from).not.toHaveBeenCalled();
      expect(upload).not.toHaveBeenCalled();
      expect(rpc).not.toHaveBeenCalled();
    },
  );

  it("denies unauthorized replace, primary, and delete before writes", async () => {
    const from = vi.fn();
    const rpc = vi.fn();
    const upload = vi.fn();
    const remove = vi.fn();
    authorizeCmsRequest.mockResolvedValue({ kind: "unauthorized" });
    createSupabaseServerClient.mockResolvedValue({
      from,
      rpc,
      storage: { from: () => ({ upload, remove }) },
    });

    const replaceData = new FormData();
    replaceData.set("image", pngFile());
    const { replaceProductImage } = await import(
      "@/features/media/actions/replace-product-image"
    );
    await expect(
      replaceProductImage(
        PRODUCT_ID,
        IMAGE_ID,
        INITIAL_REPLACE_MEDIA_FORM_STATE,
        replaceData,
      ),
    ).resolves.toMatchObject({ message: MEDIA_AUTH_DENIED_MESSAGE });

    const { setProductImagePrimary } = await import(
      "@/features/media/actions/set-product-image-primary"
    );
    await expect(
      setProductImagePrimary(
        PRODUCT_ID,
        IMAGE_ID,
        INITIAL_PRIMARY_MEDIA_FORM_STATE,
        new FormData(),
      ),
    ).resolves.toMatchObject({ message: MEDIA_AUTH_DENIED_MESSAGE });

    const deleteData = new FormData();
    deleteData.set("confirmed", "yes");
    const { deleteProductImage } = await import(
      "@/features/media/actions/delete-product-image"
    );
    await expect(
      deleteProductImage(
        PRODUCT_ID,
        IMAGE_ID,
        INITIAL_DELETE_MEDIA_FORM_STATE,
        deleteData,
      ),
    ).resolves.toMatchObject({ message: MEDIA_AUTH_DENIED_MESSAGE });

    expect(from).not.toHaveBeenCalled();
    expect(rpc).not.toHaveBeenCalled();
    expect(upload).not.toHaveBeenCalled();
    expect(remove).not.toHaveBeenCalled();
  });

  it("denies unauthorized update and reorder before writes", async () => {
    const from = vi.fn();
    const rpc = vi.fn();
    authorizeCmsRequest.mockResolvedValue({ kind: "unauthorized" });
    createSupabaseServerClient.mockResolvedValue({
      from,
      rpc,
    });

    const updateData = new FormData();
    updateData.set("alt_text", "Updated");
    updateData.set("sort_order", "0");
    const { updateProductImage } = await import(
      "@/features/media/actions/update-product-image"
    );
    await expect(
      updateProductImage(
        PRODUCT_ID,
        IMAGE_ID,
        INITIAL_UPDATE_MEDIA_FORM_STATE,
        updateData,
      ),
    ).resolves.toMatchObject({ message: MEDIA_AUTH_DENIED_MESSAGE });

    const reorderData = new FormData();
    reorderData.append("image_ids", IMAGE_ID);
    const { reorderProductImages } = await import(
      "@/features/media/actions/reorder-product-images"
    );
    await expect(
      reorderProductImages(
        PRODUCT_ID,
        INITIAL_REORDER_MEDIA_FORM_STATE,
        reorderData,
      ),
    ).resolves.toMatchObject({ message: MEDIA_AUTH_DENIED_MESSAGE });

    expect(from).not.toHaveBeenCalled();
    expect(rpc).not.toHaveBeenCalled();
  });
});
