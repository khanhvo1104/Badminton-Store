import { beforeEach, describe, expect, it, vi } from "vitest";

import { INITIAL_BRAND_FORM_STATE } from "@/features/brands/brand-form-state";
import {
  BRAND_AUTH_DENIED_MESSAGE,
  BRAND_LOGO_CLEANUP_WARNING,
  BRAND_SLUG_CONFLICT_MESSAGE,
} from "@/features/brands/constants";

const requireBrandActionAuth = vi.hoisted(() => vi.fn());
const revalidatePath = vi.hoisted(() => vi.fn());
const redirect = vi.hoisted(() => vi.fn());

vi.mock("@/features/brands/action-utils", async () => {
  const actual = await vi.importActual<
    typeof import("@/features/brands/action-utils")
  >("@/features/brands/action-utils");
  return { ...actual, requireBrandActionAuth };
});

vi.mock("next/cache", () => ({ revalidatePath }));
vi.mock("next/navigation", () => ({ redirect }));

const ROOT = "20000000-0000-4000-8000-000000000001";

function formData(overrides: Record<string, string> = {}) {
  const data = new FormData();
  data.set("id", overrides.id ?? ROOT);
  data.set("name", overrides.name ?? "Yonex");
  data.set("slug", overrides.slug ?? "yonex");
  data.set("description", overrides.description ?? "");
  data.set("website_url", overrides.website_url ?? "https://www.yonex.com");
  data.set("country_of_origin", overrides.country_of_origin ?? "Japan");
  data.set("sort_order", overrides.sort_order ?? "10");
  data.set("is_active", overrides.is_active ?? "true");
  return data;
}

const existingRow = {
  id: ROOT,
  name: "Yonex",
  slug: "yonex",
  description: null,
  logo_path: `brand-assets/${ROOT}/old.png`,
  website_url: "https://www.yonex.com",
  country_of_origin: "Japan",
  sort_order: 10,
  is_active: true,
};

describe("updateBrand", () => {
  beforeEach(() => {
    requireBrandActionAuth.mockReset();
    revalidatePath.mockReset();
    redirect.mockReset();
    redirect.mockImplementation((path: string) => {
      throw new Error(`NEXT_REDIRECT:${path}`);
    });
  });

  it("denies unauthorized callers without writing", async () => {
    const update = vi.fn();
    requireBrandActionAuth.mockResolvedValue({
      ok: false,
      state: {
        status: "error",
        message: BRAND_AUTH_DENIED_MESSAGE,
        fieldErrors: {},
        values: INITIAL_BRAND_FORM_STATE.values,
      },
    });

    const { updateBrand } = await import(
      "@/features/brands/actions/update-brand"
    );
    const result = await updateBrand(INITIAL_BRAND_FORM_STATE, formData());
    expect(result.message).toBe(BRAND_AUTH_DENIED_MESSAGE);
    expect(update).not.toHaveBeenCalled();
  });

  it("uploads replacement logos before deleting the previous object", async () => {
    const calls: string[] = [];
    const maybeSingle = vi.fn().mockResolvedValue({
      data: existingRow,
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

    requireBrandActionAuth.mockResolvedValue({
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
      "logo",
      new File([new Uint8Array([1, 2, 3])], "next.png", { type: "image/png" }),
    );

    const { updateBrand } = await import(
      "@/features/brands/actions/update-brand"
    );
    await expect(updateBrand(INITIAL_BRAND_FORM_STATE, data)).rejects.toThrow(
      /success=updated/,
    );

    expect(calls.indexOf("upload")).toBeLessThan(calls.indexOf("db-update"));
    expect(calls.indexOf("db-update")).toBeLessThan(calls.indexOf("remove"));
    expect(remove).toHaveBeenCalledWith([`${ROOT}/old.png`]);
  });

  it("deletes the new object and keeps the previous path if the database write fails", async () => {
    const maybeSingle = vi.fn().mockResolvedValue({
      data: existingRow,
      error: null,
    });
    const updateEq = vi.fn().mockResolvedValue({
      error: {
        code: "23505",
        message:
          'duplicate key value violates unique constraint "brands_slug_unique"',
      },
    });
    const update = vi.fn(() => ({ eq: updateEq }));
    const upload = vi.fn().mockResolvedValue({ data: {}, error: null });
    const remove = vi.fn().mockResolvedValue({ data: {}, error: null });

    requireBrandActionAuth.mockResolvedValue({
      ok: true,
      supabase: {
        from: () => ({
          select: () => ({ eq: () => ({ maybeSingle }) }),
          update,
        }),
        storage: { from: () => ({ upload, remove }) },
      },
    });

    const data = formData({ slug: "taken" });
    data.set(
      "logo",
      new File([new Uint8Array([1, 2, 3])], "next.png", { type: "image/png" }),
    );

    const { updateBrand } = await import(
      "@/features/brands/actions/update-brand"
    );
    const result = await updateBrand(INITIAL_BRAND_FORM_STATE, data);
    expect(result.message).toBe(BRAND_SLUG_CONFLICT_MESSAGE);
    expect(upload).toHaveBeenCalled();
    expect(remove).toHaveBeenCalledTimes(1);
    expect(remove.mock.calls[0]?.[0]).not.toEqual([`${ROOT}/old.png`]);
    expect(JSON.stringify(result)).not.toMatch(/23505|brands_slug_unique/i);
  });

  it("reports a sanitized cleanup warning if the previous logo cannot be removed", async () => {
    const maybeSingle = vi.fn().mockResolvedValue({
      data: existingRow,
      error: null,
    });
    const updateEq = vi.fn().mockResolvedValue({ error: null });
    const update = vi.fn(() => ({ eq: updateEq }));
    const upload = vi.fn().mockResolvedValue({ data: {}, error: null });
    const remove = vi.fn().mockResolvedValue({
      data: null,
      error: { message: "storage.objects permission denied jwt" },
    });

    requireBrandActionAuth.mockResolvedValue({
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
      "logo",
      new File([new Uint8Array([1, 2, 3])], "next.png", { type: "image/png" }),
    );

    const { updateBrand } = await import(
      "@/features/brands/actions/update-brand"
    );
    const result = await updateBrand(INITIAL_BRAND_FORM_STATE, data);
    expect(result.status).toBe("success");
    expect(result.message).toBe(BRAND_LOGO_CLEANUP_WARNING);
    expect(JSON.stringify(result)).not.toMatch(
      /storage\.objects|permission denied|jwt/i,
    );
    expect(revalidatePath).toHaveBeenCalled();
  });
});
