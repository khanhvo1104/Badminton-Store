import { beforeEach, describe, expect, it, vi } from "vitest";

import { INITIAL_CATEGORY_FORM_STATE } from "@/features/categories/category-form-state";
import { CATEGORY_AUTH_DENIED_MESSAGE } from "@/features/categories/constants";

const requireCategoryActionAuth = vi.hoisted(() => vi.fn());
const assertSafeCategoryParent = vi.hoisted(() => vi.fn());
const revalidatePath = vi.hoisted(() => vi.fn());
const redirect = vi.hoisted(() => vi.fn());

vi.mock("@/features/categories/action-utils", async () => {
  const actual = await vi.importActual<
    typeof import("@/features/categories/action-utils")
  >("@/features/categories/action-utils");
  return {
    ...actual,
    requireCategoryActionAuth,
  };
});

vi.mock("@/features/categories/hierarchy", async () => {
  const actual = await vi.importActual<
    typeof import("@/features/categories/hierarchy")
  >("@/features/categories/hierarchy");
  return {
    ...actual,
    assertSafeCategoryParent,
  };
});

vi.mock("next/cache", () => ({ revalidatePath }));
vi.mock("next/navigation", () => ({ redirect }));

describe("createCategory", () => {
  beforeEach(() => {
    requireCategoryActionAuth.mockReset();
    assertSafeCategoryParent.mockReset();
    revalidatePath.mockReset();
    redirect.mockReset();
    assertSafeCategoryParent.mockResolvedValue({ ok: true });
  });

  it("denies unauthorized callers without writing", async () => {
    requireCategoryActionAuth.mockResolvedValue({
      ok: false,
      state: {
        status: "error",
        message: CATEGORY_AUTH_DENIED_MESSAGE,
        fieldErrors: {},
        values: INITIAL_CATEGORY_FORM_STATE.values,
      },
    });

    const { createCategory } = await import(
      "@/features/categories/actions/create-category"
    );
    const formData = new FormData();
    formData.set("name", "Rackets");
    formData.set("slug", "rackets");
    formData.set("sort_order", "1");
    formData.set("is_active", "true");

    const result = await createCategory(INITIAL_CATEGORY_FORM_STATE, formData);
    expect(result.message).toBe(CATEGORY_AUTH_DENIED_MESSAGE);
  });

  it("creates a category and revalidates on success", async () => {
    const insert = vi.fn().mockResolvedValue({ error: null });
    requireCategoryActionAuth.mockResolvedValue({
      ok: true,
      supabase: {
        from: () => ({ insert }),
      },
    });

    redirect.mockImplementation(() => {
      throw new Error("NEXT_REDIRECT");
    });

    const { createCategory } = await import(
      "@/features/categories/actions/create-category"
    );
    const formData = new FormData();
    formData.set("name", "Rackets");
    formData.set("slug", "rackets");
    formData.set("sort_order", "1");
    formData.set("is_active", "true");

    await expect(
      createCategory(INITIAL_CATEGORY_FORM_STATE, formData),
    ).rejects.toThrow("NEXT_REDIRECT");
    expect(insert).toHaveBeenCalled();
    expect(revalidatePath).toHaveBeenCalled();
  });
});
