import { beforeEach, describe, expect, it, vi } from "vitest";

import { INITIAL_CATEGORY_ACTIVATION_STATE } from "@/features/categories/category-form-state";
import { CATEGORY_ACTIVATION_CONFIRM_REQUIRED_MESSAGE } from "@/features/categories/constants";

const requireCategoryActionAuth = vi.hoisted(() => vi.fn());
const revalidatePath = vi.hoisted(() => vi.fn());
const redirect = vi.hoisted(() => vi.fn());

vi.mock("@/features/categories/action-utils", async () => {
  const actual = await vi.importActual<
    typeof import("@/features/categories/action-utils")
  >("@/features/categories/action-utils");
  return { ...actual, requireCategoryActionAuth };
});

vi.mock("next/cache", () => ({ revalidatePath }));
vi.mock("next/navigation", () => ({ redirect }));

const CATEGORY_ID = "10000000-0000-4000-8000-000000000001";

describe("setCategoryActive", () => {
  beforeEach(() => {
    requireCategoryActionAuth.mockReset();
    revalidatePath.mockReset();
    redirect.mockReset();
    redirect.mockImplementation((path: string) => {
      throw new Error(`NEXT_REDIRECT:${path}`);
    });
  });

  it("requires confirmation before activation", async () => {
    requireCategoryActionAuth.mockResolvedValue({
      ok: true,
      supabase: { from: vi.fn() },
    });

    const { setCategoryActive } = await import(
      "@/features/categories/actions/set-category-active"
    );
    const formData = new FormData();
    formData.set("id", CATEGORY_ID);
    formData.set("is_active", "true");

    const result = await setCategoryActive(
      INITIAL_CATEGORY_ACTIVATION_STATE,
      formData,
    );
    expect(result.message).toBe(CATEGORY_ACTIVATION_CONFIRM_REQUIRED_MESSAGE);
    expect(result.fieldErrors.confirmed).toBe(
      CATEGORY_ACTIVATION_CONFIRM_REQUIRED_MESSAGE,
    );
  });

  it("activates after confirmation", async () => {
    const maybeSingle = vi.fn().mockResolvedValue({
      data: {
        id: CATEGORY_ID,
        parent_id: null,
        name: "Root",
        slug: "root",
        description: null,
        image_path: null,
        sort_order: 1,
        is_active: false,
      },
      error: null,
    });
    const eq = vi.fn().mockResolvedValue({ error: null });
    const update = vi.fn(() => ({ eq }));
    requireCategoryActionAuth.mockResolvedValue({
      ok: true,
      supabase: {
        from: () => ({
          select: () => ({ eq: () => ({ maybeSingle }) }),
          update,
        }),
      },
    });

    const { setCategoryActive } = await import(
      "@/features/categories/actions/set-category-active"
    );
    const formData = new FormData();
    formData.set("id", CATEGORY_ID);
    formData.set("is_active", "true");
    formData.set("confirmed", "yes");

    await expect(
      setCategoryActive(INITIAL_CATEGORY_ACTIVATION_STATE, formData),
    ).rejects.toThrow(/success=activated/);
    expect(update).toHaveBeenCalled();
  });
});
