import { beforeEach, describe, expect, it, vi } from "vitest";

import { INITIAL_CATEGORY_FORM_STATE } from "@/features/categories/category-form-state";
import {
  CATEGORY_AUTH_DENIED_MESSAGE,
  CATEGORY_PARENT_CYCLE_MESSAGE,
} from "@/features/categories/constants";

const requireCategoryActionAuth = vi.hoisted(() => vi.fn());
const assertSafeCategoryParent = vi.hoisted(() => vi.fn());
const revalidatePath = vi.hoisted(() => vi.fn());
const redirect = vi.hoisted(() => vi.fn());

vi.mock("@/features/categories/action-utils", async () => {
  const actual = await vi.importActual<
    typeof import("@/features/categories/action-utils")
  >("@/features/categories/action-utils");
  return { ...actual, requireCategoryActionAuth };
});

vi.mock("@/features/categories/hierarchy", async () => {
  const actual = await vi.importActual<
    typeof import("@/features/categories/hierarchy")
  >("@/features/categories/hierarchy");
  return { ...actual, assertSafeCategoryParent };
});

vi.mock("next/cache", () => ({ revalidatePath }));
vi.mock("next/navigation", () => ({ redirect }));

const ROOT = "10000000-0000-4000-8000-000000000001";
const CHILD = "10000000-0000-4000-8000-000000000002";

function formData(overrides: Record<string, string> = {}) {
  const data = new FormData();
  data.set("id", overrides.id ?? ROOT);
  data.set("name", overrides.name ?? "Rackets");
  data.set("slug", overrides.slug ?? "rackets");
  data.set("description", overrides.description ?? "");
  data.set("parent_id", overrides.parent_id ?? "");
  data.set("sort_order", overrides.sort_order ?? "1");
  data.set("is_active", overrides.is_active ?? "true");
  return data;
}

describe("updateCategory", () => {
  beforeEach(() => {
    requireCategoryActionAuth.mockReset();
    assertSafeCategoryParent.mockReset();
    revalidatePath.mockReset();
    redirect.mockReset();
    redirect.mockImplementation((path: string) => {
      throw new Error(`NEXT_REDIRECT:${path}`);
    });
    assertSafeCategoryParent.mockResolvedValue({ ok: true });
  });

  it("denies unauthorized callers without writing", async () => {
    const update = vi.fn();
    requireCategoryActionAuth.mockResolvedValue({
      ok: false,
      state: {
        status: "error",
        message: CATEGORY_AUTH_DENIED_MESSAGE,
        fieldErrors: {},
        values: INITIAL_CATEGORY_FORM_STATE.values,
      },
    });

    const { updateCategory } = await import(
      "@/features/categories/actions/update-category"
    );
    const result = await updateCategory(
      INITIAL_CATEGORY_FORM_STATE,
      formData(),
    );
    expect(result.message).toBe(CATEGORY_AUTH_DENIED_MESSAGE);
    expect(update).not.toHaveBeenCalled();
  });

  it("rejects descendant parents", async () => {
    assertSafeCategoryParent.mockResolvedValue({
      ok: false,
      message: CATEGORY_PARENT_CYCLE_MESSAGE,
    });

    const maybeSingle = vi.fn().mockResolvedValue({
      data: {
        id: ROOT,
        parent_id: null,
        name: "Root",
        slug: "root",
        description: null,
        image_path: null,
        sort_order: 1,
        is_active: true,
      },
      error: null,
    });
    const update = vi.fn();
    requireCategoryActionAuth.mockResolvedValue({
      ok: true,
      supabase: {
        from: () => ({
          select: () => ({ eq: () => ({ maybeSingle }) }),
          update,
        }),
      },
    });

    const { updateCategory } = await import(
      "@/features/categories/actions/update-category"
    );
    const result = await updateCategory(
      INITIAL_CATEGORY_FORM_STATE,
      formData({ parent_id: CHILD }),
    );
    expect(result.fieldErrors.parentId).toBe(CATEGORY_PARENT_CYCLE_MESSAGE);
    expect(update).not.toHaveBeenCalled();
  });

  it("uploads replacement images before deleting the previous object", async () => {
    const calls: string[] = [];
    const maybeSingle = vi.fn().mockResolvedValue({
      data: {
        id: ROOT,
        parent_id: null,
        name: "Root",
        slug: "root",
        description: null,
        image_path: `category-assets/${ROOT}/old.png`,
        sort_order: 1,
        is_active: true,
      },
      error: null,
    });
    const updateEq = vi.fn().mockImplementation(async () => {
      calls.push("db-update");
      return { error: null };
    });
    const update = vi.fn(() => ({ eq: updateEq }));
    const upload = vi.fn().mockImplementation(async () => {
      calls.push("upload");
      return { data: {}, error: null };
    });
    const remove = vi.fn().mockImplementation(async () => {
      calls.push("remove");
      return { data: {}, error: null };
    });

    requireCategoryActionAuth.mockResolvedValue({
      ok: true,
      supabase: {
        from: () => ({
          select: () => ({ eq: () => ({ maybeSingle }) }),
          update,
        }),
        storage: { from: () => ({ upload, remove }) },
      },
    });

    const data = formData();
    data.set(
      "image",
      new File([new Uint8Array([1, 2, 3])], "next.png", { type: "image/png" }),
    );

    const { updateCategory } = await import(
      "@/features/categories/actions/update-category"
    );
    await expect(
      updateCategory(INITIAL_CATEGORY_FORM_STATE, data),
    ).rejects.toThrow(/success=updated/);

    expect(calls.indexOf("upload")).toBeLessThan(calls.indexOf("db-update"));
    expect(calls.indexOf("db-update")).toBeLessThan(calls.indexOf("remove"));
  });
});
