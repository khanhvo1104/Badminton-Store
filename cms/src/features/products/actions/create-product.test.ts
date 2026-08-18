import { beforeEach, describe, expect, it, vi } from "vitest";

import { INITIAL_PRODUCT_FORM_STATE } from "@/features/products/product-form-state";
import {
  PRODUCT_MUTATION_AUTH_DENIED_MESSAGE,
  PRODUCT_NOT_FOUND_MESSAGE,
  PRODUCT_SLUG_CONFLICT_MESSAGE,
} from "@/features/products/constants";

const requireProductActionAuth = vi.hoisted(() => vi.fn());
const revalidatePath = vi.hoisted(() => vi.fn());
const redirect = vi.hoisted(() => vi.fn());

vi.mock("@/features/products/action-utils", async () => {
  const actual = await vi.importActual<
    typeof import("@/features/products/action-utils")
  >("@/features/products/action-utils");
  return {
    ...actual,
    requireProductActionAuth,
  };
});

vi.mock("next/cache", () => ({ revalidatePath }));
vi.mock("next/navigation", () => ({ redirect }));

const CATEGORY_ID = "10000000-0000-4000-8000-000000000001";
const PRODUCT_ID = "30000000-0000-4000-8000-000000000099";

function validFormData(overrides: Record<string, string> = {}): FormData {
  const data = new FormData();
  data.set("category_id", overrides.category_id ?? CATEGORY_ID);
  data.set("brand_id", overrides.brand_id ?? "");
  data.set("name", overrides.name ?? "Aero Strike");
  data.set("slug", overrides.slug ?? "aero-strike");
  data.set("slug_manual", overrides.slug_manual ?? "true");
  data.set("short_description", overrides.short_description ?? "");
  data.set("description", overrides.description ?? "");
  data.set("specifications", overrides.specifications ?? "");
  data.set("search_keywords", overrides.search_keywords ?? "");
  data.set("status", overrides.status ?? "draft");
  data.set("is_featured", overrides.is_featured ?? "false");
  data.set("published_at", overrides.published_at ?? "");
  return data;
}

describe("createProduct", () => {
  beforeEach(() => {
    requireProductActionAuth.mockReset();
    revalidatePath.mockReset();
    redirect.mockReset();
  });

  it("denies unauthorized callers without writing", async () => {
    const insert = vi.fn();
    requireProductActionAuth.mockResolvedValue({
      ok: false,
      state: {
        status: "error",
        message: PRODUCT_MUTATION_AUTH_DENIED_MESSAGE,
        fieldErrors: {},
        values: INITIAL_PRODUCT_FORM_STATE.values,
      },
    });

    const { createProduct } = await import(
      "@/features/products/actions/create-product"
    );
    const result = await createProduct(
      INITIAL_PRODUCT_FORM_STATE,
      validFormData(),
    );
    expect(result.message).toBe(PRODUCT_MUTATION_AUTH_DENIED_MESSAGE);
    expect(insert).not.toHaveBeenCalled();
  });

  it("creates a product and revalidates on success", async () => {
    const insert = vi.fn().mockResolvedValue({ error: null });
    const from = vi.fn(() => ({ insert }));
    requireProductActionAuth.mockResolvedValue({
      ok: true,
      supabase: {
        from: vi.fn((table: string) => {
          if (table === "products") {
            return { insert };
          }
          return {
            select: vi.fn(() => ({
              eq: vi.fn(() => ({
                maybeSingle: vi.fn().mockResolvedValue({
                  data: { id: CATEGORY_ID, is_active: true },
                  error: null,
                }),
              })),
            })),
          };
        }),
      },
    });
    redirect.mockImplementation(() => {
      throw new Error("NEXT_REDIRECT");
    });

    const { createProduct } = await import(
      "@/features/products/actions/create-product"
    );
    await expect(
      createProduct(INITIAL_PRODUCT_FORM_STATE, validFormData()),
    ).rejects.toThrow("NEXT_REDIRECT");
    expect(from).not.toHaveBeenCalled();
    expect(insert).toHaveBeenCalled();
    expect(revalidatePath).toHaveBeenCalledWith("/dashboard/products");
    expect(revalidatePath).toHaveBeenCalledWith("/dashboard/products/new");
  });

  it("returns a sanitized slug conflict", async () => {
    const insert = vi.fn().mockResolvedValue({
      error: {
        code: "23505",
        message:
          'duplicate key value violates unique constraint "products_slug_unique"',
      },
    });
    requireProductActionAuth.mockResolvedValue({
      ok: true,
      supabase: {
        from: vi.fn((table: string) => {
          if (table === "products") {
            return { insert };
          }
          return {
            select: vi.fn(() => ({
              eq: vi.fn(() => ({
                maybeSingle: vi.fn().mockResolvedValue({
                  data: { id: CATEGORY_ID, is_active: true },
                  error: null,
                }),
              })),
            })),
          };
        }),
      },
    });

    const { createProduct } = await import(
      "@/features/products/actions/create-product"
    );
    const result = await createProduct(
      INITIAL_PRODUCT_FORM_STATE,
      validFormData(),
    );
    expect(result.fieldErrors.slug).toBe(PRODUCT_SLUG_CONFLICT_MESSAGE);
    expect(result.message).toBe(PRODUCT_SLUG_CONFLICT_MESSAGE);
  });
});

describe("updateProduct", () => {
  beforeEach(() => {
    requireProductActionAuth.mockReset();
    revalidatePath.mockReset();
    redirect.mockReset();
  });

  it("rejects invalid product ids before writing", async () => {
    const update = vi.fn();
    requireProductActionAuth.mockResolvedValue({
      ok: true,
      supabase: { from: () => ({ update }) },
    });

    const { updateProduct } = await import(
      "@/features/products/actions/update-product"
    );
    const formData = validFormData();
    formData.set("id", "not-a-uuid");

    const result = await updateProduct(INITIAL_PRODUCT_FORM_STATE, formData);
    expect(result.message).toBe(PRODUCT_NOT_FOUND_MESSAGE);
    expect(update).not.toHaveBeenCalled();
  });

  it("returns not found when the product row is missing", async () => {
    requireProductActionAuth.mockResolvedValue({
      ok: true,
      supabase: {
        from: vi.fn(() => ({
          select: vi.fn(() => ({
            eq: vi.fn(() => ({
              maybeSingle: vi
                .fn()
                .mockResolvedValue({ data: null, error: null }),
            })),
          })),
          update: vi.fn(),
        })),
      },
    });

    const { updateProduct } = await import(
      "@/features/products/actions/update-product"
    );
    const formData = validFormData();
    formData.set("id", PRODUCT_ID);

    const result = await updateProduct(INITIAL_PRODUCT_FORM_STATE, formData);
    expect(result.message).toBe(PRODUCT_NOT_FOUND_MESSAGE);
  });
});
