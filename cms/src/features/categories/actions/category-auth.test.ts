import { beforeEach, describe, expect, it, vi } from "vitest";

import { INITIAL_CATEGORY_FORM_STATE } from "@/features/categories/category-form-state";
import {
  CATEGORY_AUTH_DENIED_MESSAGE,
  CATEGORY_ACTIVATION_CONFIRM_REQUIRED_MESSAGE,
} from "@/features/categories/constants";
import { INITIAL_CATEGORY_ACTIVATION_STATE } from "@/features/categories/category-form-state";

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

describe("category server actions auth", () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it("denies unauthorized create without mutating", async () => {
    authorizeCmsRequest.mockResolvedValue({ kind: "anonymous" });
    createSupabaseServerClient.mockResolvedValue({});

    const { createCategory } = await import(
      "@/features/categories/actions/create-category"
    );
    const formData = new FormData();
    formData.set("name", "Shoes");
    formData.set("slug", "shoes");
    formData.set("sort_order", "0");

    await expect(
      createCategory(INITIAL_CATEGORY_FORM_STATE, formData),
    ).resolves.toMatchObject({
      status: "error",
      message: CATEGORY_AUTH_DENIED_MESSAGE,
    });
  });

  it("requires activation confirmation before writes", async () => {
    const { setCategoryActive } = await import(
      "@/features/categories/actions/set-category-active"
    );
    const formData = new FormData();
    formData.set("id", "11111111-1111-4111-8111-111111111111");
    formData.set("is_active", "false");

    await expect(
      setCategoryActive(INITIAL_CATEGORY_ACTIVATION_STATE, formData),
    ).resolves.toMatchObject({
      status: "error",
      message: CATEGORY_ACTIVATION_CONFIRM_REQUIRED_MESSAGE,
    });
    expect(createSupabaseServerClient).not.toHaveBeenCalled();
  });
});
