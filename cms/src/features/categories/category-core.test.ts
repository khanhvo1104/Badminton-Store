import { describe, expect, it, vi } from "vitest";

import {
  CATEGORY_IMAGE_INVALID_MESSAGE,
  CATEGORY_PAGE_SIZE_DEFAULT,
  CATEGORY_PAGE_SIZE_MAX,
  CATEGORY_SLUG_CONFLICT_MESSAGE,
} from "@/features/categories/constants";
import {
  assertNoProviderLeak,
  toCategoryMutationFailureMessage,
} from "@/features/categories/errors";
import {
  buildCategoryImagePublicUrl,
  buildCategoryObjectPath,
  toStoredCategoryImagePath,
  validateCategoryImageFile,
} from "@/features/categories/image";
import { mapCategoryListItem } from "@/features/categories/mappers";
import { listCategories } from "@/features/categories/queries";
import {
  categoryEditPath,
  getCategoryRevalidationPaths,
} from "@/features/categories/revalidate";
import {
  normalizeCategorySlug,
  parseCategoryFormInput,
  parseCategoryPagination,
} from "@/features/categories/validation";

const ID = "10000000-0000-4000-8000-000000000001";
const PARENT = "10000000-0000-4000-8000-000000000002";

describe("category validation and pagination", () => {
  it("clamps page and pageSize and computes inclusive ranges", () => {
    expect(parseCategoryPagination({})).toEqual({
      page: 1,
      pageSize: CATEGORY_PAGE_SIZE_DEFAULT,
      from: 0,
      to: CATEGORY_PAGE_SIZE_DEFAULT - 1,
    });
    expect(parseCategoryPagination({ page: "0", pageSize: "999" })).toEqual({
      page: 1,
      pageSize: CATEGORY_PAGE_SIZE_MAX,
      from: 0,
      to: CATEGORY_PAGE_SIZE_MAX - 1,
    });
    expect(parseCategoryPagination({ page: "2", pageSize: "10" })).toEqual({
      page: 2,
      pageSize: 10,
      from: 10,
      to: 19,
    });
  });

  it("normalizes slugs and rejects invalid form input", () => {
    expect(normalizeCategorySlug(" Hello World ")).toBe("hello-world");

    const formData = new FormData();
    formData.set("name", "");
    formData.set("slug", "");
    formData.set("sort_order", "1.5");
    formData.set("parent_id", "not-a-uuid");

    const parsed = parseCategoryFormInput(formData);
    expect(parsed.ok).toBe(false);
    if (!parsed.ok) {
      expect(parsed.fieldErrors.name).toBeTruthy();
      expect(parsed.fieldErrors.slug).toBeTruthy();
      expect(parsed.fieldErrors.sortOrder).toBeTruthy();
      expect(parsed.fieldErrors.parentId).toBeTruthy();
    }
  });
});

describe("category image helpers", () => {
  it("validates mime allow-list and size", () => {
    expect(validateCategoryImageFile(null)).toEqual({ ok: true, image: null });
    expect(
      validateCategoryImageFile(
        new File([new Uint8Array([1])], "a.gif", { type: "image/gif" }),
      ),
    ).toEqual({ ok: false, message: CATEGORY_IMAGE_INVALID_MESSAGE });

    const ok = validateCategoryImageFile(
      new File([new Uint8Array([1, 2, 3])], "evil/../x.png", {
        type: "image/png",
      }),
    );
    expect(ok.ok).toBe(true);
    if (ok.ok && ok.image) {
      expect(ok.image.extension).toBe(".png");
    }
  });

  it("generates object paths under the category id", () => {
    const path = buildCategoryObjectPath(
      ID,
      ".webp",
      () => "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa",
    );
    expect(path).toBe(`${ID}/aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa.webp`);
    expect(toStoredCategoryImagePath(path)).toBe(`category-assets/${path}`);
    expect(
      buildCategoryImagePublicUrl(
        "https://example.supabase.co",
        `category-assets/${ID}/main.webp`,
      ),
    ).toBe(
      `https://example.supabase.co/storage/v1/object/public/category-assets/${ID}/main.webp`,
    );
  });
});

describe("category errors and revalidation", () => {
  it("sanitizes slug conflicts and provider leaks", () => {
    const message = toCategoryMutationFailureMessage({
      code: "23505",
      message:
        'duplicate key value violates unique constraint "categories_slug_unique"',
    });
    expect(message).toBe(CATEGORY_SLUG_CONFLICT_MESSAGE);
    expect(assertNoProviderLeak(message)).toBe(true);
    expect(assertNoProviderLeak("storage.objects permission denied jwt")).toBe(
      false,
    );
  });

  it("lists revalidation paths for mutations", () => {
    expect(getCategoryRevalidationPaths(ID)).toEqual([
      "/dashboard/categories",
      "/dashboard/categories/new",
      categoryEditPath(ID),
    ]);
  });
});

describe("category list query", () => {
  it("orders deterministically before range and maps parent names", async () => {
    const orderCalls: Array<{ column: string; ascending?: boolean }> = [];
    const range = vi.fn().mockResolvedValue({
      data: [
        {
          id: ID,
          parent_id: PARENT,
          name: "Rackets",
          slug: "rackets",
          description: null,
          image_path: null,
          sort_order: 10,
          is_active: true,
        },
      ],
      error: null,
      count: 21,
    });
    const listBuilder = {
      order(column: string, options?: { ascending?: boolean }) {
        orderCalls.push({ column, ascending: options?.ascending });
        return listBuilder;
      },
      range,
    };

    const listed = await listCategories({
      supabase: {
        from: () => ({
          select: (columns: string) => {
            if (columns === "id, name") {
              return {
                in: async () => ({
                  data: [{ id: PARENT, name: "Sports" }],
                  error: null,
                }),
              };
            }
            return listBuilder;
          },
        }),
      } as never,
      pagination: { page: 2, pageSize: 20, from: 20, to: 39 },
      supabaseUrl: "https://example.supabase.co",
    });

    expect(orderCalls).toEqual([
      { column: "sort_order", ascending: true },
      { column: "name", ascending: true },
      { column: "id", ascending: true },
    ]);
    expect(range).toHaveBeenCalledWith(20, 39);
    expect(listed.ok).toBe(true);
    if (listed.ok) {
      expect(listed.result.totalCount).toBe(21);
      expect(listed.result.totalPages).toBe(2);
      expect(listed.result.items[0]?.parentName).toBe("Sports");
    }

    const mapped = mapCategoryListItem(
      {
        id: ID,
        parent_id: PARENT,
        name: "Rackets",
        slug: "rackets",
        description: null,
        image_path: null,
        sort_order: 10,
        is_active: true,
      },
      "Sports",
      "https://example.supabase.co",
    );
    expect(mapped.parentName).toBe("Sports");
    expect(mapped.sortOrder).toBe(10);
  });
});
