import { beforeEach, describe, expect, it, vi } from "vitest";

import { INITIAL_BRAND_FORM_STATE } from "@/features/brands/brand-form-state";
import {
  BRAND_AUTH_DENIED_MESSAGE,
  BRAND_LOGO_INVALID_MESSAGE,
  BRAND_SLUG_CONFLICT_MESSAGE,
  BRAND_WEBSITE_INVALID_MESSAGE,
} from "@/features/brands/constants";

const requireBrandActionAuth = vi.hoisted(() => vi.fn());
const revalidatePath = vi.hoisted(() => vi.fn());
const redirect = vi.hoisted(() => vi.fn());

vi.mock("@/features/brands/action-utils", async () => {
  const actual = await vi.importActual<
    typeof import("@/features/brands/action-utils")
  >("@/features/brands/action-utils");
  return {
    ...actual,
    requireBrandActionAuth,
  };
});

vi.mock("next/cache", () => ({ revalidatePath }));
vi.mock("next/navigation", () => ({ redirect }));

const BRAND_ID = "20000000-0000-4000-8000-000000000099";

function validFormData(overrides: Record<string, string> = {}): FormData {
  const data = new FormData();
  data.set("name", overrides.name ?? "Yonex");
  data.set("slug", overrides.slug ?? "yonex");
  data.set("description", overrides.description ?? "");
  data.set("website_url", overrides.website_url ?? "https://www.yonex.com");
  data.set("country_of_origin", overrides.country_of_origin ?? "Japan");
  data.set("sort_order", overrides.sort_order ?? "10");
  data.set("is_active", overrides.is_active ?? "true");
  return data;
}

describe("createBrand", () => {
  beforeEach(() => {
    requireBrandActionAuth.mockReset();
    revalidatePath.mockReset();
    redirect.mockReset();
  });

  it("denies unauthorized callers without writing", async () => {
    const insert = vi.fn();
    const upload = vi.fn();
    requireBrandActionAuth.mockResolvedValue({
      ok: false,
      state: {
        status: "error",
        message: BRAND_AUTH_DENIED_MESSAGE,
        fieldErrors: {},
        values: INITIAL_BRAND_FORM_STATE.values,
      },
    });

    const { createBrand } = await import(
      "@/features/brands/actions/create-brand"
    );
    const result = await createBrand(INITIAL_BRAND_FORM_STATE, validFormData());
    expect(result.message).toBe(BRAND_AUTH_DENIED_MESSAGE);
    expect(insert).not.toHaveBeenCalled();
    expect(upload).not.toHaveBeenCalled();
  });

  it("rejects invalid website URLs before writes", async () => {
    const insert = vi.fn();
    requireBrandActionAuth.mockResolvedValue({
      ok: true,
      supabase: { from: () => ({ insert }), storage: { from: vi.fn() } },
    });

    const { createBrand } = await import(
      "@/features/brands/actions/create-brand"
    );
    const result = await createBrand(
      INITIAL_BRAND_FORM_STATE,
      validFormData({ website_url: "http://yonex.com" }),
    );
    expect(result.fieldErrors.websiteUrl).toBe(BRAND_WEBSITE_INVALID_MESSAGE);
    expect(insert).not.toHaveBeenCalled();
  });

  it("rejects invalid logos before writes", async () => {
    const insert = vi.fn();
    const upload = vi.fn();
    requireBrandActionAuth.mockResolvedValue({
      ok: true,
      supabase: {
        from: () => ({ insert }),
        storage: { from: () => ({ upload }) },
      },
    });

    const data = validFormData();
    data.set(
      "logo",
      new File([new Uint8Array([1])], "logo.gif", { type: "image/gif" }),
    );

    const { createBrand } = await import(
      "@/features/brands/actions/create-brand"
    );
    const result = await createBrand(INITIAL_BRAND_FORM_STATE, data);
    expect(result.fieldErrors.logo).toBe(BRAND_LOGO_INVALID_MESSAGE);
    expect(insert).not.toHaveBeenCalled();
    expect(upload).not.toHaveBeenCalled();
  });

  it("creates a brand and revalidates on success", async () => {
    const insert = vi.fn().mockResolvedValue({ error: null });
    requireBrandActionAuth.mockResolvedValue({
      ok: true,
      supabase: { from: () => ({ insert }) },
    });
    redirect.mockImplementation(() => {
      throw new Error("NEXT_REDIRECT");
    });

    const { createBrand } = await import(
      "@/features/brands/actions/create-brand"
    );
    await expect(
      createBrand(INITIAL_BRAND_FORM_STATE, validFormData()),
    ).rejects.toThrow("NEXT_REDIRECT");
    expect(insert).toHaveBeenCalled();
    expect(revalidatePath).toHaveBeenCalledWith("/dashboard/brands");
    expect(revalidatePath).toHaveBeenCalledWith("/dashboard/brands/new");
  });

  it("returns a sanitized slug conflict and does not leak provider text", async () => {
    const insert = vi.fn().mockResolvedValue({
      error: {
        code: "23505",
        message:
          'duplicate key value violates unique constraint "brands_slug_unique"',
      },
    });
    requireBrandActionAuth.mockResolvedValue({
      ok: true,
      supabase: { from: () => ({ insert }) },
    });

    const { createBrand } = await import(
      "@/features/brands/actions/create-brand"
    );
    const result = await createBrand(INITIAL_BRAND_FORM_STATE, validFormData());
    expect(result.message).toBe(BRAND_SLUG_CONFLICT_MESSAGE);
    expect(result.fieldErrors.slug).toBe(BRAND_SLUG_CONFLICT_MESSAGE);
    expect(JSON.stringify(result)).not.toMatch(/23505|brands_slug_unique|sql/i);
  });

  it("deletes a newly uploaded logo if the database insert fails", async () => {
    vi.spyOn(crypto, "randomUUID").mockReturnValue(BRAND_ID);
    const insert = vi.fn().mockResolvedValue({
      error: { message: "insert failed" },
    });
    const upload = vi.fn().mockResolvedValue({ data: {}, error: null });
    const remove = vi.fn().mockResolvedValue({ data: {}, error: null });
    requireBrandActionAuth.mockResolvedValue({
      ok: true,
      supabase: {
        from: () => ({ insert }),
        storage: { from: () => ({ upload, remove }) },
      },
    });

    const data = validFormData();
    data.set(
      "logo",
      new File([new Uint8Array([1, 2, 3])], "submitted-name.png", {
        type: "image/png",
      }),
    );

    const { createBrand } = await import(
      "@/features/brands/actions/create-brand"
    );
    const result = await createBrand(INITIAL_BRAND_FORM_STATE, data);
    expect(result.status).toBe("error");
    expect(upload).toHaveBeenCalled();
    expect(insert).toHaveBeenCalled();
    expect(remove).toHaveBeenCalled();
    const uploadedPath = String(upload.mock.calls[0]?.[0] ?? "");
    expect(uploadedPath.startsWith(`${BRAND_ID}/`)).toBe(true);
    expect(uploadedPath).not.toContain("submitted-name");
    expect(remove.mock.calls[0]?.[0]).toEqual([uploadedPath]);
    expect(JSON.stringify(result)).not.toMatch(/insert failed/i);
    vi.restoreAllMocks();
  });
});
