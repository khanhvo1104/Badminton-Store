import { beforeEach, describe, expect, it, vi } from "vitest";

import { INITIAL_BRAND_ACTIVATION_STATE } from "@/features/brands/brand-form-state";
import { INITIAL_BRAND_FORM_STATE } from "@/features/brands/brand-form-state";
import {
  BRAND_ACTIVATION_CONFIRM_REQUIRED_MESSAGE,
  BRAND_AUTH_DENIED_MESSAGE,
} from "@/features/brands/constants";

const redirect = vi.hoisted(() => vi.fn());
const revalidatePath = vi.hoisted(() => vi.fn());
const createSupabaseServerClient = vi.hoisted(() => vi.fn());
const authorizeCmsRequest = vi.hoisted(() => vi.fn());

vi.mock("next/navigation", () => ({ redirect }));
vi.mock("next/cache", () => ({ revalidatePath }));
vi.mock("@/lib/supabase/server", () => ({ createSupabaseServerClient }));
vi.mock("@/lib/auth/authorization", async () => {
  const actual = await vi.importActual<
    typeof import("@/lib/auth/authorization")
  >("@/lib/auth/authorization");
  return { ...actual, authorizeCmsRequest };
});

function brandFormData(): FormData {
  const formData = new FormData();
  formData.set("name", "Yonex");
  formData.set("slug", "yonex");
  formData.set("sort_order", "0");
  formData.set("website_url", "https://www.yonex.com");
  return formData;
}

describe("brand server actions auth", () => {
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
    "denies %s create without mutating brands or storage",
    async (_label, authorization) => {
      const from = vi.fn();
      const upload = vi.fn();
      authorizeCmsRequest.mockResolvedValue(authorization);
      createSupabaseServerClient.mockResolvedValue({
        from,
        storage: { from: () => ({ upload }) },
      });

      const { createBrand } = await import(
        "@/features/brands/actions/create-brand"
      );
      await expect(
        createBrand(INITIAL_BRAND_FORM_STATE, brandFormData()),
      ).resolves.toMatchObject({
        status: "error",
        message: BRAND_AUTH_DENIED_MESSAGE,
      });
      expect(from).not.toHaveBeenCalled();
      expect(upload).not.toHaveBeenCalled();
    },
  );

  it("denies unauthorized edit without writing", async () => {
    const from = vi.fn();
    authorizeCmsRequest.mockResolvedValue({ kind: "unauthorized" });
    createSupabaseServerClient.mockResolvedValue({ from });

    const { updateBrand } = await import(
      "@/features/brands/actions/update-brand"
    );
    const formData = brandFormData();
    formData.set("id", "20000000-0000-4000-8000-000000000001");

    await expect(
      updateBrand(INITIAL_BRAND_FORM_STATE, formData),
    ).resolves.toMatchObject({
      status: "error",
      message: BRAND_AUTH_DENIED_MESSAGE,
    });
    expect(from).not.toHaveBeenCalled();
  });

  it("requires activation confirmation before writes", async () => {
    const { setBrandActive } = await import(
      "@/features/brands/actions/set-brand-active"
    );
    const formData = new FormData();
    formData.set("id", "11111111-1111-4111-8111-111111111111");
    formData.set("is_active", "false");

    await expect(
      setBrandActive(INITIAL_BRAND_ACTIVATION_STATE, formData),
    ).resolves.toMatchObject({
      status: "error",
      message: BRAND_ACTIVATION_CONFIRM_REQUIRED_MESSAGE,
    });
    expect(createSupabaseServerClient).not.toHaveBeenCalled();
  });
});
