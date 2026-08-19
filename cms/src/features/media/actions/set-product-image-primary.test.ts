import { beforeEach, describe, expect, it, vi } from "vitest";

import {
  MEDIA_GENERIC_FAILURE_MESSAGE,
  MEDIA_NOT_FOUND_MESSAGE,
  MEDIA_SUCCESS_PRIMARY,
  SET_CMS_PRODUCT_IMAGE_PRIMARY_RPC,
  productMediaPath,
} from "@/features/media/constants";
import { INITIAL_PRIMARY_MEDIA_FORM_STATE } from "@/features/media/form-state";

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

describe("setProductImagePrimary", () => {
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
    requireMediaActionAuth.mockResolvedValue({ ok: true, supabase: { rpc } });

    const data = new FormData();
    data.set("product_id", "30000000-0000-4000-8000-000000000088");
    data.set("image_id", FORGED_IMAGE);

    const { setProductImagePrimary } = await import(
      "@/features/media/actions/set-product-image-primary"
    );
    await expect(
      setProductImagePrimary(
        PRODUCT_ID,
        IMAGE_ID,
        INITIAL_PRIMARY_MEDIA_FORM_STATE,
        data,
      ),
    ).rejects.toThrow(`success=${MEDIA_SUCCESS_PRIMARY}`);

    expect(rpc).toHaveBeenCalledWith(SET_CMS_PRODUCT_IMAGE_PRIMARY_RPC, {
      p_product_id: PRODUCT_ID,
      p_image_id: IMAGE_ID,
    });
    expect(revalidatePath).toHaveBeenCalledWith(productMediaPath(PRODUCT_ID));
  });

  it.each([
    ["empty", []],
    ["null", null],
    ["bare UUID string", IMAGE_ID],
    ["multiple", [{ image_id: IMAGE_ID }, { image_id: IMAGE_ID }]],
    ["mismatched", [{ image_id: FORGED_IMAGE }]],
    ["protected cost_price", [{ image_id: IMAGE_ID, cost_price: "1" }]],
  ])("fail-closes %s RPC payloads", async (_label, payload) => {
    const rpc = vi.fn().mockResolvedValue({ data: payload, error: null });
    requireMediaActionAuth.mockResolvedValue({ ok: true, supabase: { rpc } });
    const { setProductImagePrimary } = await import(
      "@/features/media/actions/set-product-image-primary"
    );
    const result = await setProductImagePrimary(
      PRODUCT_ID,
      IMAGE_ID,
      INITIAL_PRIMARY_MEDIA_FORM_STATE,
      new FormData(),
    );
    expect(result.message).toBe(MEDIA_GENERIC_FAILURE_MESSAGE);
    expect(redirect).not.toHaveBeenCalled();
  });

  it("rejects a forged non-uuid route image id before rpc", async () => {
    const rpc = vi.fn();
    requireMediaActionAuth.mockResolvedValue({ ok: true, supabase: { rpc } });
    const { setProductImagePrimary } = await import(
      "@/features/media/actions/set-product-image-primary"
    );
    const result = await setProductImagePrimary(
      PRODUCT_ID,
      "not-a-uuid",
      INITIAL_PRIMARY_MEDIA_FORM_STATE,
      new FormData(),
    );
    expect(result.message).toBe(MEDIA_NOT_FOUND_MESSAGE);
    expect(rpc).not.toHaveBeenCalled();
  });
});
