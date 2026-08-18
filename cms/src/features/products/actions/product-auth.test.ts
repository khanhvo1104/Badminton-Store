import { beforeEach, describe, expect, it, vi } from "vitest";

import { INITIAL_PRODUCT_FORM_STATE } from "@/features/products/product-form-state";
import { PRODUCT_MUTATION_AUTH_DENIED_MESSAGE } from "@/features/products/constants";

const createSupabaseServerClient = vi.hoisted(() => vi.fn());
const authorizeCmsRequest = vi.hoisted(() => vi.fn());

vi.mock("@/lib/supabase/server", () => ({ createSupabaseServerClient }));
vi.mock("@/lib/auth/authorization", async () => {
  const actual = await vi.importActual<
    typeof import("@/lib/auth/authorization")
  >("@/lib/auth/authorization");
  return { ...actual, authorizeCmsRequest };
});

function productFormData(): FormData {
  const formData = new FormData();
  formData.set("category_id", "10000000-0000-4000-8000-000000000001");
  formData.set("name", "Aero Strike");
  formData.set("slug", "aero-strike");
  formData.set("slug_manual", "true");
  formData.set("status", "draft");
  return formData;
}

describe("product server actions auth", () => {
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
    "denies %s create without mutating products",
    async (_label, authorization) => {
      const from = vi.fn();
      authorizeCmsRequest.mockResolvedValue(authorization);
      createSupabaseServerClient.mockResolvedValue({ from });

      const { createProduct } = await import(
        "@/features/products/actions/create-product"
      );
      await expect(
        createProduct(INITIAL_PRODUCT_FORM_STATE, productFormData()),
      ).resolves.toMatchObject({
        status: "error",
        message: PRODUCT_MUTATION_AUTH_DENIED_MESSAGE,
      });
      expect(from).not.toHaveBeenCalled();
    },
  );

  it("denies unauthorized edit without writing", async () => {
    const from = vi.fn();
    authorizeCmsRequest.mockResolvedValue({ kind: "unauthorized" });
    createSupabaseServerClient.mockResolvedValue({ from });

    const { updateProduct } = await import(
      "@/features/products/actions/update-product"
    );
    const formData = productFormData();
    formData.set("id", "30000000-0000-4000-8000-000000000001");

    await expect(
      updateProduct(INITIAL_PRODUCT_FORM_STATE, formData),
    ).resolves.toMatchObject({
      status: "error",
      message: PRODUCT_MUTATION_AUTH_DENIED_MESSAGE,
    });
    expect(from).not.toHaveBeenCalled();
  });
});
