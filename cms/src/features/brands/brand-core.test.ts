import { describe, expect, it, vi } from "vitest";

import {
  BRAND_LOGO_INVALID_MESSAGE,
  BRAND_PAGE_SIZE_DEFAULT,
  BRAND_PAGE_SIZE_MAX,
  BRAND_SLUG_CONFLICT_MESSAGE,
  BRAND_WEBSITE_INVALID_MESSAGE,
} from "@/features/brands/constants";
import {
  assertNoProviderLeak,
  toBrandMutationFailureMessage,
} from "@/features/brands/errors";
import {
  buildBrandLogoPublicUrl,
  buildBrandObjectPath,
  toStoredBrandLogoPath,
  validateBrandLogoFile,
} from "@/features/brands/logo";
import { mapBrandListItem } from "@/features/brands/mappers";
import { listBrands } from "@/features/brands/queries";
import {
  brandEditPath,
  getBrandRevalidationPaths,
} from "@/features/brands/revalidate";
import {
  normalizeBrandSlug,
  parseAbsoluteHttpsUrl,
  parseBrandFormInput,
  parseBrandPagination,
} from "@/features/brands/validation";

const ID = "20000000-0000-4000-8000-000000000001";

function formDataFrom(entries: Record<string, string>): FormData {
  const data = new FormData();
  for (const [key, value] of Object.entries(entries)) {
    data.set(key, value);
  }
  return data;
}

describe("brand validation and pagination", () => {
  it("clamps page and pageSize and computes inclusive ranges", () => {
    expect(parseBrandPagination({})).toEqual({
      page: 1,
      pageSize: BRAND_PAGE_SIZE_DEFAULT,
      from: 0,
      to: BRAND_PAGE_SIZE_DEFAULT - 1,
    });
    expect(parseBrandPagination({ page: "0", pageSize: "999" })).toEqual({
      page: 1,
      pageSize: BRAND_PAGE_SIZE_MAX,
      from: 0,
      to: BRAND_PAGE_SIZE_MAX - 1,
    });
    expect(parseBrandPagination({ page: "2", pageSize: "10" })).toEqual({
      page: 2,
      pageSize: 10,
      from: 10,
      to: 19,
    });
    expect(parseBrandPagination({ page: "abc", pageSize: "-3" })).toEqual({
      page: 1,
      pageSize: BRAND_PAGE_SIZE_DEFAULT,
      from: 0,
      to: BRAND_PAGE_SIZE_DEFAULT - 1,
    });
  });

  it("normalizes slugs and rejects invalid form input", () => {
    expect(normalizeBrandSlug(" Yonex Pro ")).toBe("yonex-pro");

    const parsed = parseBrandFormInput(
      formDataFrom({
        name: "",
        slug: "",
        sort_order: "1.5",
        website_url: "http://example.com",
        country_of_origin: "x".repeat(81),
      }),
    );
    expect(parsed.ok).toBe(false);
    if (!parsed.ok) {
      expect(parsed.fieldErrors.name).toBeTruthy();
      expect(parsed.fieldErrors.slug).toBeTruthy();
      expect(parsed.fieldErrors.sortOrder).toBeTruthy();
      expect(parsed.fieldErrors.websiteUrl).toBe(BRAND_WEBSITE_INVALID_MESSAGE);
      expect(parsed.fieldErrors.countryOfOrigin).toBeTruthy();
      expect(parsed.values.websiteUrl).toBe("http://example.com");
    }
  });

  it("accepts optional HTTPS websites and keeps submitted values", () => {
    expect(parseAbsoluteHttpsUrl("")).toBeNull();
    expect(parseAbsoluteHttpsUrl("https://yonex.com")).toBe(
      "https://yonex.com",
    );
    expect(parseAbsoluteHttpsUrl("javascript:alert(1)")).toBeNull();
    expect(parseAbsoluteHttpsUrl("https://user:pass@evil.test")).toBeNull();
    expect(parseAbsoluteHttpsUrl("//yonex.com")).toBeNull();

    const parsed = parseBrandFormInput(
      formDataFrom({
        name: "Yonex",
        slug: "Yonex Brand",
        description: "Demo",
        website_url: "https://www.yonex.com/badminton",
        country_of_origin: "Japan",
        sort_order: "10",
        is_active: "true",
      }),
    );
    expect(parsed.ok).toBe(true);
    if (parsed.ok) {
      expect(parsed.data.slug).toBe("yonex-brand");
      expect(parsed.data.websiteUrl).toBe("https://www.yonex.com/badminton");
      expect(parsed.data.countryOfOrigin).toBe("Japan");
      expect(parsed.values.websiteUrl).toBe("https://www.yonex.com/badminton");
    }
  });
});

describe("brand logo helpers", () => {
  it("validates mime allow-list, non-empty content, and size", () => {
    expect(validateBrandLogoFile(null)).toEqual({ ok: true, logo: null });
    expect(
      validateBrandLogoFile(
        new File([new Uint8Array([1])], "a.gif", { type: "image/gif" }),
      ),
    ).toEqual({ ok: false, message: BRAND_LOGO_INVALID_MESSAGE });
    expect(
      validateBrandLogoFile(new File([], "empty.png", { type: "image/png" })),
    ).toEqual({ ok: false, message: BRAND_LOGO_INVALID_MESSAGE });

    const tooLarge = new File(
      [new Uint8Array(2 * 1024 * 1024 + 1)],
      "big.png",
      { type: "image/png" },
    );
    expect(validateBrandLogoFile(tooLarge)).toEqual({
      ok: false,
      message: BRAND_LOGO_INVALID_MESSAGE,
    });

    const ok = validateBrandLogoFile(
      new File([new Uint8Array([1, 2, 3])], "evil/../x.svg", {
        type: "image/svg+xml",
      }),
    );
    expect(ok.ok).toBe(true);
    if (ok.ok && ok.logo) {
      expect(ok.logo.extension).toBe(".svg");
    }
  });

  it("generates object paths under the brand id and ignores submitted names", () => {
    const path = buildBrandObjectPath(
      ID,
      ".webp",
      () => "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa",
    );
    expect(path).toBe(`${ID}/aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa.webp`);
    expect(path).not.toContain("evil");
    expect(toStoredBrandLogoPath(path)).toBe(`brand-assets/${path}`);
    expect(
      buildBrandLogoPublicUrl(
        "https://example.supabase.co",
        `brand-assets/${ID}/logo.svg`,
      ),
    ).toBe(
      `https://example.supabase.co/storage/v1/object/public/brand-assets/${ID}/logo.svg`,
    );
  });
});

describe("brand errors and revalidation", () => {
  it("sanitizes slug conflicts and provider leaks", () => {
    const message = toBrandMutationFailureMessage({
      code: "23505",
      message:
        'duplicate key value violates unique constraint "brands_slug_unique"',
    });
    expect(message).toBe(BRAND_SLUG_CONFLICT_MESSAGE);
    expect(assertNoProviderLeak(message)).toBe(true);
    expect(
      assertNoProviderLeak("storage.objects permission denied jwt token"),
    ).toBe(false);
    expect(
      toBrandMutationFailureMessage({
        message: "PGRST116 relation brands does not exist",
      }),
    ).toBe("We couldn't save that brand. Check your input and try again.");
  });

  it("lists revalidation paths for mutations", () => {
    expect(getBrandRevalidationPaths(ID)).toEqual([
      "/dashboard/brands",
      "/dashboard/brands/new",
      brandEditPath(ID),
    ]);
  });
});

describe("brand list query", () => {
  it("orders deterministically before range and maps brand rows", async () => {
    const orderCalls: Array<{ column: string; ascending?: boolean }> = [];
    const range = vi.fn().mockResolvedValue({
      data: [
        {
          id: ID,
          name: "Yonex",
          slug: "yonex",
          description: null,
          logo_path: `brand-assets/${ID}/logo.webp`,
          website_url: "https://www.yonex.com",
          country_of_origin: "Japan",
          sort_order: 10,
          is_active: false,
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

    const listed = await listBrands({
      supabase: {
        from: (table: string) => {
          expect(table).toBe("brands");
          return {
            select: (columns: string) => {
              expect(columns).not.toContain("*");
              expect(columns).toContain("logo_path");
              return listBuilder;
            },
          };
        },
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
      expect(listed.result.items[0]?.countryOfOrigin).toBe("Japan");
      expect(listed.result.items[0]?.isActive).toBe(false);
      expect(listed.result.items[0]?.logoUrl).toContain(
        `/storage/v1/object/public/brand-assets/${ID}/logo.webp`,
      );
    }

    const mapped = mapBrandListItem(
      {
        id: ID,
        name: "Yonex",
        slug: "yonex",
        description: null,
        logo_path: null,
        website_url: "https://www.yonex.com",
        country_of_origin: "Japan",
        sort_order: 10,
        is_active: true,
      },
      "https://example.supabase.co",
    );
    expect(mapped.websiteUrl).toBe("https://www.yonex.com");
    expect(mapped.sortOrder).toBe(10);
  });
});
