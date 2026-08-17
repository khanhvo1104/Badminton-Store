import { describe, expect, it, vi } from "vitest";

import {
  PRODUCT_AUTH_DENIED_MESSAGE,
  PRODUCT_FILTER_OPTION_LIMIT,
  PRODUCT_LIST_COLUMNS,
  PRODUCT_LOAD_FAILURE_MESSAGE,
  PRODUCT_PAGE_SIZE_DEFAULT,
  PRODUCT_PAGE_SIZE_MAX,
  PRODUCT_RELATED_FETCH_LIMIT,
  PRODUCT_VARIANT_LIST_COLUMNS,
} from "@/features/products/constants";
import { assertNoProviderLeak } from "@/features/products/errors";
import { buildProductImagePublicUrl } from "@/features/products/image";
import {
  aggregateInventory,
  availableQuantity,
  productMatchesStockFilter,
} from "@/features/products/inventory";
import {
  compareProductListItems,
  mapProductListItem,
  mapProductRow,
} from "@/features/products/mappers";
import {
  compareSellingPrices,
  formatPriceRange,
  formatSellingPrice,
  parseSellingPrice,
} from "@/features/products/money";
import {
  listProductCategoryOptions,
  listProducts,
} from "@/features/products/queries";
import {
  buildProductSearchOrFilter,
  planProductSearch,
  sanitizeProductSearchLiteral,
} from "@/features/products/search";
import type { ProductExplorerQuery } from "@/features/products/types";
import {
  getProductListOrder,
  parseProductExplorerQuery,
  parseProductPagination,
  productExplorerHasActiveFilters,
  productExplorerHref,
} from "@/features/products/validation";

const PRODUCT_ID = "30000000-0000-4000-8000-000000000001";
const PRODUCT_ID_B = "30000000-0000-4000-8000-000000000002";
const CATEGORY_ID = "10000000-0000-4000-8000-000000000001";
const BRAND_ID = "20000000-0000-4000-8000-000000000001";
const VARIANT_ID = "40000000-0000-4000-8000-000000000001";
const VARIANT_ID_B = "40000000-0000-4000-8000-000000000002";

const authorizeCmsRequest = vi.hoisted(() => vi.fn());

vi.mock("@/lib/auth/authorization", async () => {
  const actual = await vi.importActual<
    typeof import("@/lib/auth/authorization")
  >("@/lib/auth/authorization");
  return { ...actual, authorizeCmsRequest };
});

function defaultQuery(
  overrides: Partial<ProductExplorerQuery> = {},
): ProductExplorerQuery {
  return {
    search: "",
    categoryId: null,
    brandId: null,
    status: null,
    stock: "all",
    sort: "updated_desc",
    pagination: {
      page: 1,
      pageSize: PRODUCT_PAGE_SIZE_DEFAULT,
      from: 0,
      to: PRODUCT_PAGE_SIZE_DEFAULT - 1,
    },
    ...overrides,
  };
}

describe("product explorer query parsing", () => {
  it("clamps page values and computes zero-based inclusive ranges", () => {
    expect(parseProductPagination({})).toEqual({
      page: 1,
      pageSize: PRODUCT_PAGE_SIZE_DEFAULT,
      from: 0,
      to: PRODUCT_PAGE_SIZE_DEFAULT - 1,
    });
    expect(parseProductPagination({ page: "0", pageSize: "999" })).toEqual({
      page: 1,
      pageSize: PRODUCT_PAGE_SIZE_MAX,
      from: 0,
      to: PRODUCT_PAGE_SIZE_MAX - 1,
    });
    expect(parseProductPagination({ page: "2", pageSize: "10" })).toEqual({
      page: 2,
      pageSize: 10,
      from: 10,
      to: 19,
    });
    expect(parseProductPagination({ page: "abc", pageSize: "-3" })).toEqual({
      page: 1,
      pageSize: PRODUCT_PAGE_SIZE_DEFAULT,
      from: 0,
      to: PRODUCT_PAGE_SIZE_DEFAULT - 1,
    });
  });

  it("falls back to safe defaults for invalid uuid, enum, and page values", () => {
    const parsed = parseProductExplorerQuery({
      page: "nope",
      q: "  Yonex  ",
      category: "not-a-uuid",
      brand: "also-bad",
      status: "deleted",
      stock: "negative",
      sort: "price_random",
    });

    expect(parsed).toMatchObject({
      search: "Yonex",
      categoryId: null,
      brandId: null,
      status: null,
      stock: "all",
      sort: "updated_desc",
      pagination: {
        page: 1,
        pageSize: PRODUCT_PAGE_SIZE_DEFAULT,
        from: 0,
        to: PRODUCT_PAGE_SIZE_DEFAULT - 1,
      },
    });
  });

  it("round-trips valid filters through the shareable href", () => {
    const query = parseProductExplorerQuery({
      page: "3",
      q: "aero",
      category: CATEGORY_ID,
      brand: BRAND_ID,
      status: "draft",
      stock: "low_stock",
      sort: "price_asc",
    });

    expect(query.categoryId).toBe(CATEGORY_ID);
    expect(query.brandId).toBe(BRAND_ID);
    expect(query.status).toBe("draft");
    expect(query.stock).toBe("low_stock");
    expect(query.sort).toBe("price_asc");
    expect(productExplorerHasActiveFilters(query)).toBe(true);
    expect(productExplorerHref(query)).toBe(
      `/dashboard/products?q=aero&category=${CATEGORY_ID}&brand=${BRAND_ID}&status=draft&stock=low_stock&sort=price_asc&page=3`,
    );
    expect(
      productExplorerHref({
        search: "",
        categoryId: null,
        brandId: null,
        status: null,
        stock: "all",
        sort: "updated_desc",
        pagination: { page: 2, pageSize: 10 },
      }),
    ).toBe("/dashboard/products?pageSize=10&page=2");
  });

  it("uses id as the final sort tie-breaker for every sort contract", () => {
    for (const sort of [
      "updated_desc",
      "updated_asc",
      "name_asc",
      "name_desc",
      "price_asc",
      "price_desc",
    ] as const) {
      const order = getProductListOrder(sort);
      expect(order.at(-1)).toEqual({ column: "id", ascending: true });
    }
  });
});

describe("product search escaping", () => {
  it("bounds length and strips LIKE wildcards from attacker-controlled text", () => {
    expect(sanitizeProductSearchLiteral("  %Yonex_Pro%  ")).toBe("YonexPro");
    expect(planProductSearch("   ")).toEqual({ kind: "none" });
    expect(planProductSearch("%_%")).toEqual({ kind: "none-match" });
    const bounded = planProductSearch("a".repeat(200));
    expect(bounded.kind).toBe("or");
    if (bounded.kind === "or") {
      expect(bounded.literal).toHaveLength(80);
    }
  });

  it("quotes commas, parentheses, quotes, and operators inside a fixed or-filter", () => {
    const attacks = [
      "*),status.eq.draft,name.eq.",
      'foo","status.eq.active',
      "or(status.eq.archived)",
      "100%",
    ];

    for (const attack of attacks) {
      const plan = planProductSearch(attack);
      if (plan.kind !== "or") {
        expect(plan.kind).toBe("none-match");
        continue;
      }
      expect(plan.filter).toBe(buildProductSearchOrFilter(plan.literal));
      expect(plan.filter.startsWith("name.ilike.")).toBe(true);
      expect(plan.filter.split(",slug.ilike.")).toHaveLength(2);
    }
  });
});

describe("price and inventory mapping", () => {
  it("rejects malformed prices and distinguishes missing from numeric zero", () => {
    expect(parseSellingPrice("0.00")).toBe("0.00");
    expect(parseSellingPrice("1890000.00")).toBe("1890000.00");
    expect(parseSellingPrice(1890000)).toBe("1890000");
    expect(parseSellingPrice("12.345")).toBeNull();
    expect(parseSellingPrice("not-a-price")).toBeNull();
    expect(parseSellingPrice(-1)).toBeNull();
    expect(formatSellingPrice("0")).toBe("0₫");
    expect(formatPriceRange(null, null)).toBe("No price");
    expect(formatPriceRange("0", "0")).toBe("0₫");
    expect(compareSellingPrices("10.00", "10.50")).toBe(-1);
  });

  it("aggregates inventory without treating missing rows as zero stock", () => {
    expect(availableQuantity(4, 6)).toBe(0);
    expect(availableQuantity(8, 3)).toBe(5);

    const missing = aggregateInventory({ variantCount: 2, rows: [] });
    expect(missing?.hasMissingInventory).toBe(true);
    expect(missing?.totalOnHand).toBeNull();
    expect(missing?.totalAvailable).toBeNull();
    expect(missing?.stockLabel).toBe("Inventory incomplete");
    expect(productMatchesStockFilter(missing!, "missing")).toBe(true);
    expect(productMatchesStockFilter(missing!, "out_of_stock")).toBe(false);

    const zero = aggregateInventory({
      variantCount: 1,
      rows: [{ quantityOnHand: 0, quantityReserved: 0, reorderLevel: 2 }],
    });
    expect(zero?.totalOnHand).toBe(0);
    expect(zero?.totalAvailable).toBe(0);
    expect(zero?.isLowStock).toBe(true);
    expect(zero?.stockLabel).toBe("Out of stock");
    expect(productMatchesStockFilter(zero!, "out_of_stock")).toBe(true);
    expect(productMatchesStockFilter(zero!, "low_stock")).toBe(true);

    const low = aggregateInventory({
      variantCount: 1,
      rows: [{ quantityOnHand: 4, quantityReserved: 1, reorderLevel: 5 }],
    });
    expect(low?.totalAvailable).toBe(3);
    expect(low?.isLowStock).toBe(true);
    expect(low?.stockLabel).toBe("Low stock");
  });

  it("places products without prices after priced rows for both price sorts", () => {
    const priced = listItem({ minAmount: "10", maxAmount: "12" });
    const missing = listItem({
      id: PRODUCT_ID_B,
      minAmount: null,
      maxAmount: null,
    });

    expect(compareProductListItems(missing, priced, "price_asc")).toBe(1);
    expect(compareProductListItems(missing, priced, "price_desc")).toBe(1);
  });

  it("maps a product row with primary image URL and never inlines SVG", () => {
    const item = mapProductListItem({
      row: {
        id: PRODUCT_ID,
        category_id: CATEGORY_ID,
        brand_id: BRAND_ID,
        name: "Aero Strike",
        slug: "aero-strike",
        status: "active",
        is_featured: true,
        published_at: "2026-01-01T00:00:00.000Z",
        updated_at: "2026-01-02T00:00:00.000Z",
      },
      categoryName: "Rackets",
      brandName: "Yonex",
      variants: [
        {
          id: VARIANT_ID,
          product_id: PRODUCT_ID,
          price: "1890000.00",
          is_active: true,
        },
        {
          id: VARIANT_ID_B,
          product_id: PRODUCT_ID,
          price: "1920000.00",
          is_active: false,
        },
      ],
      inventoryByVariantId: new Map([
        [
          VARIANT_ID,
          {
            variant_id: VARIANT_ID,
            quantity_on_hand: 8,
            quantity_reserved: 2,
            reorder_level: 3,
          },
        ],
      ]),
      primaryImagePath: `product-images/${PRODUCT_ID}/main.webp`,
      supabaseUrl: "https://example.supabase.co",
    });

    expect(item?.categoryName).toBe("Rackets");
    expect(item?.activeVariantCount).toBe(1);
    expect(item?.totalVariantCount).toBe(2);
    expect(item?.priceRange.label).toBe("1.890.000₫ – 1.920.000₫");
    expect(item?.inventory.hasMissingInventory).toBe(true);
    expect(item?.inventory.totalAvailable).toBe(6);
    expect(item?.primaryImageUrl).toBe(
      buildProductImagePublicUrl(
        "https://example.supabase.co",
        `product-images/${PRODUCT_ID}/main.webp`,
      ),
    );
    expect(item?.primaryImageUrl).not.toContain("<svg");
    expect(mapProductRow({ id: "bad" })).toBeNull();
  });
});

describe("product list query", () => {
  it("authorizes before inventory reads and keeps related queries bounded", async () => {
    authorizeCmsRequest.mockResolvedValue({
      kind: "authorized",
      profile: {
        id: "staff-1",
        fullName: "Alex Coach",
        role: "staff",
        isActive: true,
      },
    });

    const calls: Array<{
      table: string;
      columns?: string;
      eq: Array<[string, unknown]>;
      is: Array<[string, unknown]>;
      in: Array<[string, string[]]>;
      or: string[];
      order: Array<{ column: string; ascending?: boolean }>;
      range?: [number, number];
      limit?: number;
    }> = [];

    const listed = await listProducts({
      supabase: createExplorerClient(calls, {
        products: [
          {
            id: PRODUCT_ID,
            category_id: CATEGORY_ID,
            brand_id: BRAND_ID,
            name: "Aero Strike",
            slug: "aero-strike",
            status: "draft",
            is_featured: false,
            published_at: null,
            updated_at: "2026-01-02T00:00:00.000Z",
          },
        ],
        productCount: 21,
        variants: [
          {
            id: VARIANT_ID,
            product_id: PRODUCT_ID,
            price: "1890000.00",
            is_active: true,
          },
        ],
        inventory: [
          {
            variant_id: VARIANT_ID,
            quantity_on_hand: 4,
            quantity_reserved: 1,
            reorder_level: 2,
          },
        ],
        images: [
          {
            product_id: PRODUCT_ID,
            storage_path: `product-images/${PRODUCT_ID}/main.webp`,
            variant_id: null,
            is_primary: true,
          },
        ],
        categories: [{ id: CATEGORY_ID, name: "Rackets" }],
        brands: [{ id: BRAND_ID, name: "Yonex" }],
      }),
      query: defaultQuery({
        search: "aero,or(status.eq.archived)",
        categoryId: CATEGORY_ID,
        brandId: BRAND_ID,
        status: "draft",
        pagination: { page: 2, pageSize: 20, from: 20, to: 39 },
      }),
      supabaseUrl: "https://example.supabase.co",
    });

    const productCall = calls.find((call) => call.table === "products");
    expect(productCall?.columns).toBe(PRODUCT_LIST_COLUMNS);
    expect(productCall?.columns).not.toContain("*");
    expect(productCall?.eq).toEqual([
      ["category_id", CATEGORY_ID],
      ["brand_id", BRAND_ID],
      ["status", "draft"],
    ]);
    expect(productCall?.or[0]).toBe(
      buildProductSearchOrFilter(
        sanitizeProductSearchLiteral("aero,or(status.eq.archived)"),
      ),
    );
    expect(productCall?.order).toEqual([
      { column: "updated_at", ascending: false },
      { column: "id", ascending: true },
    ]);
    expect(productCall?.range).toEqual([20, 39]);

    const variantCall = calls.find((call) => call.table === "product_variants");
    expect(variantCall?.columns).toBe(PRODUCT_VARIANT_LIST_COLUMNS);
    expect(variantCall?.columns).not.toContain("cost_price");
    expect(variantCall?.columns).not.toContain("barcode");
    expect(variantCall?.in[0]?.[1]).toEqual([PRODUCT_ID]);
    expect(variantCall?.limit).toBe(PRODUCT_RELATED_FETCH_LIMIT);

    const inventoryCall = calls.find((call) => call.table === "inventory");
    expect(inventoryCall?.in[0]?.[1]).toEqual([VARIANT_ID]);
    expect(inventoryCall?.limit).toBe(PRODUCT_RELATED_FETCH_LIMIT);

    expect(
      calls.every((call) => !String(call.columns ?? "").includes("cost_price")),
    ).toBe(true);
    expect(calls.every((call) => call.columns !== "*")).toBe(true);
    expect(listed.ok).toBe(true);
    if (listed.ok) {
      expect(listed.result.totalCount).toBe(21);
      expect(listed.result.totalPages).toBe(2);
      expect(listed.result.items[0]?.brandName).toBe("Yonex");
      expect(listed.result.items[0]?.statusLabel).toBe("Draft");
    }
  });

  it("applies stock filters after bounded related reads and sorts missing prices last", async () => {
    authorizeCmsRequest.mockResolvedValue({
      kind: "authorized",
      profile: {
        id: "staff-1",
        fullName: "Alex Coach",
        role: "staff",
        isActive: true,
      },
    });

    const listed = await listProducts({
      supabase: createExplorerClient([], {
        products: [
          {
            id: PRODUCT_ID,
            category_id: CATEGORY_ID,
            brand_id: null,
            name: "Priced racket",
            slug: "priced-racket",
            status: "active",
            is_featured: false,
            published_at: "2026-01-01T00:00:00.000Z",
            updated_at: "2026-01-02T00:00:00.000Z",
          },
          {
            id: PRODUCT_ID_B,
            category_id: CATEGORY_ID,
            brand_id: null,
            name: "No variants",
            slug: "no-variants",
            status: "draft",
            is_featured: false,
            published_at: null,
            updated_at: "2026-01-03T00:00:00.000Z",
          },
        ],
        productCount: 2,
        variants: [
          {
            id: VARIANT_ID,
            product_id: PRODUCT_ID,
            price: "50.00",
            is_active: true,
          },
        ],
        inventory: [
          {
            variant_id: VARIANT_ID,
            quantity_on_hand: 0,
            quantity_reserved: 0,
            reorder_level: 2,
          },
        ],
        images: [],
        categories: [{ id: CATEGORY_ID, name: "Rackets" }],
        brands: [],
      }),
      query: defaultQuery({
        stock: "out_of_stock",
        sort: "price_desc",
      }),
      supabaseUrl: "https://example.supabase.co",
    });

    expect(listed.ok).toBe(true);
    if (listed.ok) {
      expect(listed.result.items.map((item) => item.id)).toEqual([
        PRODUCT_ID,
        PRODUCT_ID_B,
      ]);
      expect(listed.result.items[0]?.priceRange.minAmount).toBe("50.00");
      expect(listed.result.items[1]?.priceRange.minAmount).toBeNull();
    }

    const inStock = await listProducts({
      supabase: createExplorerClient([], {
        products: [
          {
            id: PRODUCT_ID,
            category_id: CATEGORY_ID,
            brand_id: null,
            name: "Priced racket",
            slug: "priced-racket",
            status: "active",
            is_featured: false,
            published_at: "2026-01-01T00:00:00.000Z",
            updated_at: "2026-01-02T00:00:00.000Z",
          },
          {
            id: PRODUCT_ID_B,
            category_id: CATEGORY_ID,
            brand_id: null,
            name: "No variants",
            slug: "no-variants",
            status: "draft",
            is_featured: false,
            published_at: null,
            updated_at: "2026-01-03T00:00:00.000Z",
          },
        ],
        productCount: 2,
        variants: [
          {
            id: VARIANT_ID,
            product_id: PRODUCT_ID,
            price: "50.00",
            is_active: true,
          },
        ],
        inventory: [
          {
            variant_id: VARIANT_ID,
            quantity_on_hand: 0,
            quantity_reserved: 0,
            reorder_level: 2,
          },
        ],
        images: [],
        categories: [{ id: CATEGORY_ID, name: "Rackets" }],
        brands: [],
      }),
      query: defaultQuery({ stock: "in_stock" }),
      supabaseUrl: "https://example.supabase.co",
    });

    expect(inStock.ok).toBe(true);
    if (inStock.ok) {
      expect(inStock.result.items).toEqual([]);
    }
  });

  it("does not query inventory when authorization is denied", async () => {
    authorizeCmsRequest.mockResolvedValue({ kind: "unauthorized" });
    const calls: Array<{ table: string }> = [];

    const listed = await listProducts({
      supabase: createExplorerClient(calls, {}),
      query: defaultQuery(),
      supabaseUrl: "https://example.supabase.co",
    });

    expect(listed).toEqual({
      ok: false,
      message: PRODUCT_AUTH_DENIED_MESSAGE,
    });
    expect(calls).toEqual([]);
    expect(assertNoProviderLeak(PRODUCT_LOAD_FAILURE_MESSAGE)).toBe(true);
    expect(assertNoProviderLeak("postgrest permission denied jwt")).toBe(false);
  });

  it("fails closed on malformed provider rows without leaking details", async () => {
    authorizeCmsRequest.mockResolvedValue({
      kind: "authorized",
      profile: {
        id: "staff-1",
        fullName: "Alex Coach",
        role: "staff",
        isActive: true,
      },
    });
    const listed = await listProducts({
      supabase: createExplorerClient([], {
        products: [{ id: "bad-row", boom: "sql token=secret" }],
        productCount: 1,
      }),
      query: defaultQuery(),
      supabaseUrl: "https://example.supabase.co",
    });

    expect(listed).toEqual({
      ok: false,
      message: PRODUCT_LOAD_FAILURE_MESSAGE,
    });
    expect(JSON.stringify(listed)).not.toMatch(/sql|token=secret/i);
  });

  it("loads category filters with bounded explicit ordered reads", async () => {
    const calls: Array<Record<string, unknown>> = [];
    const listed = await listProductCategoryOptions({
      supabase: createExplorerClient(calls, {
        categories: [
          {
            id: CATEGORY_ID,
            name: "Rackets",
            is_active: false,
          },
        ],
      }),
    });

    expect(listed).toEqual({
      ok: true,
      options: [{ id: CATEGORY_ID, name: "Rackets", isActive: false }],
    });
    expect(calls[0]).toMatchObject({
      table: "categories",
      columns: "id, name, is_active",
      order: [
        { column: "name", ascending: true },
        { column: "id", ascending: true },
      ],
      limit: PRODUCT_FILTER_OPTION_LIMIT,
    });
  });
});

function listItem(options: {
  id?: string;
  minAmount: string | null;
  maxAmount: string | null;
}) {
  return {
    id: options.id ?? PRODUCT_ID,
    name: "Product",
    slug: "product",
    categoryId: CATEGORY_ID,
    categoryName: "Rackets",
    brandId: null,
    brandName: null,
    status: "active" as const,
    statusLabel: "Active",
    isFeatured: false,
    featuredLabel: "Not featured",
    publishedAt: null,
    publishedAtLabel: "Not published",
    updatedAt: "2026-01-02T00:00:00.000Z",
    updatedAtLabel: "2 Jan 2026, 00:00",
    primaryImageUrl: null,
    activeVariantCount: 0,
    totalVariantCount: 0,
    priceRange: {
      minAmount: options.minAmount,
      maxAmount: options.maxAmount,
      label: formatPriceRange(options.minAmount, options.maxAmount),
    },
    inventory: aggregateInventory({ variantCount: 0, rows: [] })!,
  };
}

function createExplorerClient(
  calls: Array<Record<string, unknown>>,
  fixtures: {
    products?: unknown[];
    productCount?: number;
    variants?: unknown[];
    inventory?: unknown[];
    images?: unknown[];
    categories?: unknown[];
    brands?: unknown[];
  },
) {
  return {
    auth: {
      getClaims: async () => ({ data: { claims: null }, error: null }),
    },
    from(table: string) {
      const state = {
        table,
        columns: undefined as string | undefined,
        eq: [] as Array<[string, unknown]>,
        is: [] as Array<[string, unknown]>,
        in: [] as Array<[string, string[]]>,
        or: [] as string[],
        order: [] as Array<{ column: string; ascending?: boolean }>,
        range: undefined as [number, number] | undefined,
        limit: undefined as number | undefined,
      };
      const builder = {
        select(columns: string) {
          state.columns = columns;
          return builder;
        },
        eq(column: string, value: unknown) {
          state.eq.push([column, value]);
          return builder;
        },
        is(column: string, value: unknown) {
          state.is.push([column, value]);
          return builder;
        },
        in(column: string, values: string[]) {
          state.in.push([column, values]);
          return builder;
        },
        or(filters: string) {
          state.or.push(filters);
          return builder;
        },
        order(column: string, options?: { ascending?: boolean }) {
          state.order.push({ column, ascending: options?.ascending });
          return builder;
        },
        range(from: number, to: number) {
          state.range = [from, to];
          calls.push({ ...state });
          return Promise.resolve({
            data: fixtures.products ?? [],
            error: null,
            count: fixtures.productCount ?? 0,
          });
        },
        limit(count: number) {
          state.limit = count;
          calls.push({ ...state });
          if (table === "product_variants") {
            return Promise.resolve({
              data: fixtures.variants ?? [],
              error: null,
            });
          }
          if (table === "inventory") {
            return Promise.resolve({
              data: fixtures.inventory ?? [],
              error: null,
            });
          }
          if (table === "product_images") {
            return Promise.resolve({
              data: fixtures.images ?? [],
              error: null,
            });
          }
          if (table === "categories") {
            return Promise.resolve({
              data: fixtures.categories ?? [],
              error: null,
            });
          }
          if (table === "brands") {
            return Promise.resolve({
              data: fixtures.brands ?? [],
              error: null,
            });
          }
          return Promise.resolve({ data: [], error: null });
        },
      };
      return builder;
    },
  } as never;
}
