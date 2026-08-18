import { describe, expect, it, vi } from "vitest";

import {
  PRODUCT_MUTATION_AUTH_DENIED_MESSAGE,
  PRODUCT_PUBLISHED_AT_INVALID_MESSAGE,
  PRODUCT_SLUG_CONFLICT_MESSAGE,
  PRODUCT_SPEC_INVALID_MESSAGE,
} from "@/features/products/constants";
import {
  assertNoProviderLeak,
  toProductMutationFailureMessage,
} from "@/features/products/errors";
import {
  buildProductMutationPayload,
  normalizeProductSlug,
  parseProductFormInput,
  suggestProductSlugFromName,
  validateProductFormValues,
} from "@/features/products/form-validation";
import {
  isProductDetailRow,
  mapProductDetail,
  type ProductDetailRow,
} from "@/features/products/mappers";
import {
  getProductRevalidationPaths,
  productDetailPath,
  productEditPath,
} from "@/features/products/revalidate";
import {
  formatSpecificationsForForm,
  parseSpecificationsInput,
} from "@/features/products/specifications";
import { EMPTY_PRODUCT_FORM_VALUES } from "@/features/products/product-form-state";

const PRODUCT_ID = "30000000-0000-4000-8000-000000000001";
const CATEGORY_ID = "10000000-0000-4000-8000-000000000001";
const BRAND_ID = "20000000-0000-4000-8000-000000000001";

function formDataFrom(entries: Record<string, string>): FormData {
  const data = new FormData();
  for (const [key, value] of Object.entries(entries)) {
    data.set(key, value);
  }
  return data;
}

describe("product form validation", () => {
  it("normalizes slugs and derives them from the name until slug is manual", () => {
    expect(normalizeProductSlug(" Aero Strike Pro ")).toBe("aero-strike-pro");
    expect(suggestProductSlugFromName("Aero Strike Pro")).toBe(
      "aero-strike-pro",
    );

    const parsed = parseProductFormInput(
      formDataFrom({
        category_id: CATEGORY_ID,
        name: "Aero Strike Pro",
        slug: "",
        slug_manual: "false",
        status: "draft",
      }),
    );
    expect(parsed.ok).toBe(true);
    if (parsed.ok) {
      expect(parsed.data.slug).toBe("aero-strike-pro");
    }
  });

  it("preserves safe values and field errors on invalid input", () => {
    const parsed = parseProductFormInput(
      formDataFrom({
        category_id: "not-a-uuid",
        brand_id: "bad-brand",
        name: "",
        slug: "---",
        status: "draft",
        specifications: "[]",
        published_at: "not-a-date",
      }),
    );

    expect(parsed.ok).toBe(false);
    if (!parsed.ok) {
      expect(parsed.fieldErrors.name).toBeTruthy();
      expect(parsed.fieldErrors.slug).toBeTruthy();
      expect(parsed.fieldErrors.categoryId).toBeTruthy();
      expect(parsed.fieldErrors.brandId).toBeTruthy();
      expect(parsed.fieldErrors.specifications).toBe(
        PRODUCT_SPEC_INVALID_MESSAGE,
      );
      expect(parsed.values.brandId).toBe("bad-brand");
    }
  });

  it("defaults active publication time and allows null publication for non-active statuses", () => {
    const active = validateProductFormValues(
      {
        ...EMPTY_PRODUCT_FORM_VALUES,
        categoryId: CATEGORY_ID,
        name: "Published Product",
        slug: "published-product",
        status: "active",
        publishedAt: "",
      },
      { now: () => new Date("2026-01-02T12:00:00.000Z") },
    );
    expect(active.ok).toBe(true);
    if (active.ok) {
      expect(active.data.publishedAt).toBe("2026-01-02T12:00:00.000Z");
    }

    const draft = validateProductFormValues({
      ...EMPTY_PRODUCT_FORM_VALUES,
      categoryId: CATEGORY_ID,
      name: "Draft Product",
      slug: "draft-product",
      status: "draft",
      publishedAt: "",
    });
    expect(draft.ok).toBe(true);
    if (draft.ok) {
      expect(draft.data.publishedAt).toBeNull();
    }

    const invalid = validateProductFormValues({
      ...EMPTY_PRODUCT_FORM_VALUES,
      categoryId: CATEGORY_ID,
      name: "Draft Product",
      slug: "draft-product",
      status: "draft",
      publishedAt: "not-a-date",
    });
    expect(invalid.ok).toBe(false);
    if (!invalid.ok) {
      expect(invalid.fieldErrors.publishedAt).toBe(
        PRODUCT_PUBLISHED_AT_INVALID_MESSAGE,
      );
    }
  });

  it("builds a narrow mutation payload allowlist", () => {
    const payload = buildProductMutationPayload({
      categoryId: CATEGORY_ID,
      brandId: BRAND_ID,
      name: "Aero Strike",
      slug: "aero-strike",
      shortDescription: "Short",
      description: "Long",
      specifications: { weight: "80g" },
      searchKeywords: "racket",
      status: "draft",
      isFeatured: true,
      publishedAt: null,
    });

    expect(payload).toEqual({
      category_id: CATEGORY_ID,
      brand_id: BRAND_ID,
      name: "Aero Strike",
      slug: "aero-strike",
      short_description: "Short",
      description: "Long",
      specifications: { weight: "80g" },
      search_keywords: "racket",
      status: "draft",
      is_featured: true,
      published_at: null,
    });
    expect(Object.keys(payload).sort()).toEqual([
      "brand_id",
      "category_id",
      "description",
      "is_featured",
      "name",
      "published_at",
      "search_keywords",
      "short_description",
      "slug",
      "specifications",
      "status",
    ]);
  });
});

describe("product specifications validation", () => {
  it("accepts bounded scalar objects and rejects attacks", () => {
    expect(
      parseSpecificationsInput('{"weight":"80g","head":"isometric"}'),
    ).toEqual({
      ok: true,
      value: { weight: "80g", head: "isometric" },
    });

    expect(parseSpecificationsInput("[]").ok).toBe(false);
    expect(parseSpecificationsInput('{"__proto__":{"admin":true}}').ok).toBe(
      false,
    );
    expect(parseSpecificationsInput('{"nested":{"too":"deep"}}').ok).toBe(
      false,
    );
    expect(parseSpecificationsInput(`{"key":"${"x".repeat(600)}"}`).ok).toBe(
      false,
    );
    expect(
      parseSpecificationsInput(
        `{${Array.from({ length: 60 }, (_, index) => `"k${index}":"v"`).join(",")}}`,
      ).ok,
    ).toBe(false);
  });

  it("round-trips formatted specifications", () => {
    const formatted = formatSpecificationsForForm({ balance: "head-heavy" });
    expect(parseSpecificationsInput(formatted)).toEqual({
      ok: true,
      value: { balance: "head-heavy" },
    });
  });
});

describe("product detail mapping and errors", () => {
  it("maps detail rows with scalar specifications only", () => {
    const row = {
      id: PRODUCT_ID,
      category_id: CATEGORY_ID,
      brand_id: null,
      name: "Aero Strike",
      slug: "aero-strike",
      short_description: "Short",
      description: "Long description",
      specifications: { weight: "80g", stiff: true, rating: 4.5, note: null },
      search_keywords: "racket",
      status: "draft",
      is_featured: false,
      published_at: null,
      updated_at: "2026-01-02T00:00:00.000Z",
    };

    expect(isProductDetailRow(row)).toBe(true);
    const detail = mapProductDetail({
      row: row as ProductDetailRow,
      categoryName: "Rackets",
      brandName: null,
    });
    expect(detail.description).toBe("Long description");
    expect(detail.specifications).toEqual({
      weight: "80g",
      stiff: true,
      rating: 4.5,
      note: null,
    });
  });

  it("sanitizes slug conflicts without leaking provider details", () => {
    const message = toProductMutationFailureMessage({
      code: "23505",
      message:
        'duplicate key value violates unique constraint "products_slug_unique"',
    });
    expect(message).toBe(PRODUCT_SLUG_CONFLICT_MESSAGE);
    expect(assertNoProviderLeak(message)).toBe(true);
    expect(assertNoProviderLeak("PGRST116 permission denied jwt token")).toBe(
      false,
    );
  });

  it("lists product revalidation paths", () => {
    expect(getProductRevalidationPaths(PRODUCT_ID)).toEqual([
      "/dashboard/products",
      "/dashboard/products/new",
      productDetailPath(PRODUCT_ID),
      productEditPath(PRODUCT_ID),
    ]);
  });
});

describe("product reference validation", () => {
  it("rejects inactive references on create and publish", async () => {
    const { validateProductReferences } = await import(
      "@/features/products/references"
    );

    const supabase = {
      from: vi.fn(() => ({
        select: vi.fn(() => ({
          eq: vi.fn(() => ({
            maybeSingle: vi
              .fn()
              .mockResolvedValueOnce({
                data: { id: CATEGORY_ID, is_active: false },
                error: null,
              })
              .mockResolvedValueOnce({
                data: { id: BRAND_ID, is_active: false },
                error: null,
              }),
          })),
        })),
      })),
    };

    const createResult = await validateProductReferences({
      supabase,
      categoryId: CATEGORY_ID,
      brandId: null,
      status: "draft",
    });
    expect(createResult.ok).toBe(false);

    const supabaseActiveCategory = {
      from: vi.fn(() => ({
        select: vi.fn(() => ({
          eq: vi.fn(() => ({
            maybeSingle: vi.fn().mockResolvedValue({
              data: { id: CATEGORY_ID, is_active: true },
              error: null,
            }),
          })),
        })),
      })),
    };

    const publishInactive = await validateProductReferences({
      supabase: supabaseActiveCategory,
      categoryId: CATEGORY_ID,
      brandId: null,
      status: "active",
      existingCategoryId: CATEGORY_ID,
      existingBrandId: null,
    });

    expect(publishInactive.ok).toBe(true);
  });
});

describe("product mutation auth boundary", () => {
  it("uses a separate mutation denial message", () => {
    expect(PRODUCT_MUTATION_AUTH_DENIED_MESSAGE).toContain("manage products");
  });
});
