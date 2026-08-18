import { beforeEach, describe, expect, it, vi } from "vitest";

import { INITIAL_VARIANT_FORM_STATE } from "@/features/variants/variant-form-state";
import { VARIANT_AUTH_DENIED_MESSAGE } from "@/features/variants/constants";

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
const VARIANT_ID = "40000000-0000-4000-8000-000000000001";

function variantFormData(): FormData {
  const formData = new FormData();
  formData.set("sku", "SKU-1");
  formData.set("unit", "item");
  formData.set("price", "10");
  formData.set("is_default", "false");
  formData.set("is_active", "true");
  formData.set("sort_order", "0");
  return formData;
}

describe("variant server actions auth", () => {
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
    "denies %s create without calling rpc",
    async (_label, authorization) => {
      const from = vi.fn();
      const rpc = vi.fn();
      authorizeCmsRequest.mockResolvedValue(authorization);
      createSupabaseServerClient.mockResolvedValue({ from, rpc });

      const { createVariant } = await import(
        "@/features/variants/actions/create-variant"
      );
      await expect(
        createVariant(
          PRODUCT_ID,
          INITIAL_VARIANT_FORM_STATE,
          variantFormData(),
        ),
      ).resolves.toMatchObject({
        status: "error",
        message: VARIANT_AUTH_DENIED_MESSAGE,
      });
      expect(from).not.toHaveBeenCalled();
      expect(rpc).not.toHaveBeenCalled();
    },
  );

  it("denies unauthorized edit before reading or writing", async () => {
    const from = vi.fn();
    const rpc = vi.fn();
    authorizeCmsRequest.mockResolvedValue({ kind: "unauthorized" });
    createSupabaseServerClient.mockResolvedValue({ from, rpc });

    const { updateVariant } = await import(
      "@/features/variants/actions/update-variant"
    );
    await expect(
      updateVariant(
        PRODUCT_ID,
        VARIANT_ID,
        INITIAL_VARIANT_FORM_STATE,
        variantFormData(),
      ),
    ).resolves.toMatchObject({
      status: "error",
      message: VARIANT_AUTH_DENIED_MESSAGE,
    });
    expect(from).not.toHaveBeenCalled();
    expect(rpc).not.toHaveBeenCalled();
  });
});
