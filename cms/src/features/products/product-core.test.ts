import { describe, expect, it, vi } from "vitest";

import {
  LIST_CMS_PRODUCTS_RPC,
  PRODUCT_AUTH_DENIED_MESSAGE,
  PRODUCT_FILTER_OPTION_LIMIT,
  PRODUCT_LOAD_FAILURE_MESSAGE,
  PRODUCT_PAGE_SIZE_DEFAULT,
  PRODUCT_PAGE_SIZE_MAX,
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
  getProductExplorerRpcArgs,
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

  it("sends validated offset/limit and filters to the explorer RPC", () => {
    const query = parseProductExplorerQuery({
      page: "3",
      q: "aero,or(status.eq.archived)",
      category: CATEGORY_ID,
      brand: BRAND_ID,
      status: "draft",
      stock: "low_stock",
      sort: "price_asc",
      pageSize: "10",
    });

    expect(getProductExplorerRpcArgs(query)).toEqual({
      p_search: "aero,or(status.eq.archived)",
      p_category_id: CATEGORY_ID,
      p_brand_id: BRAND_ID,
      p_status: "draft",
      p_stock: "low_stock",
      p_sort: "price_asc",
      p_offset: 20,
      p_limit: 10,
    });
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
  it("authorizes before inventory reads and pages through list_cms_products", async () => {
    authorizeCmsRequest.mockResolvedValue({
      kind: "authorized",
      profile: {
        id: "staff-1",
        fullName: "Alex Coach",
        role: "staff",
        isActive: true,
      },
    });

    const calls: Array<Record<string, unknown>> = [];

    const listed = await listProducts({
      supabase: createExplorerClient(calls, {
        rpcRows: [
          rpcExplorerRow({
            filtered_count: 21,
            brand_id: BRAND_ID,
            status: "draft",
            published_at: null,
          }),
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

    const rpcCall = calls.find((call) => call.type === "rpc");
    expect(rpcCall).toEqual({
      type: "rpc",
      fn: LIST_CMS_PRODUCTS_RPC,
      args: {
        p_search: "aero,or(status.eq.archived)",
        p_category_id: CATEGORY_ID,
        p_brand_id: BRAND_ID,
        p_status: "draft",
        p_stock: "all",
        p_sort: "updated_desc",
        p_offset: 20,
        p_limit: 20,
      },
    });
    expect(JSON.stringify(rpcCall)).not.toMatch(/cost_price|barcode/i);
    expect(JSON.stringify(rpcCall?.args)).not.toContain("name.ilike.");

    expect(calls.some((call) => call.table === "products")).toBe(false);
    expect(calls.some((call) => call.table === "product_variants")).toBe(false);
    expect(calls.some((call) => call.table === "inventory")).toBe(false);

    const imageCall = calls.find((call) => call.table === "product_images");
    expect(imageCall?.in).toEqual([["product_id", [PRODUCT_ID]]]);
    expect(imageCall?.limit).toBe(1);
    expect(String(imageCall?.columns ?? "")).not.toContain("*");

    expect(listed.ok).toBe(true);
    if (listed.ok) {
      expect(listed.result.totalCount).toBe(21);
      expect(listed.result.totalPages).toBe(2);
      expect(listed.result.items[0]?.brandName).toBe("Yonex");
      expect(listed.result.items[0]?.statusLabel).toBe("Draft");
    }
  });

  it("uses the RPC page as-is without a local stock filter or price sort", async () => {
    authorizeCmsRequest.mockResolvedValue({
      kind: "authorized",
      profile: {
        id: "staff-1",
        fullName: "Alex Coach",
        role: "staff",
        isActive: true,
      },
    });

    const calls: Array<Record<string, unknown>> = [];
    const listed = await listProducts({
      supabase: createExplorerClient(calls, {
        rpcRows: [
          rpcExplorerRow({
            id: PRODUCT_ID,
            name: "Priced racket",
            slug: "priced-racket",
            min_price: "50.00",
            max_price: "50.00",
            stock_state: "out_of_stock",
            total_on_hand: 0,
            total_reserved: 0,
            total_available: 0,
            is_low_stock: true,
            filtered_count: 2,
          }),
          rpcExplorerRow({
            id: PRODUCT_ID_B,
            name: "No variants",
            slug: "no-variants",
            status: "draft",
            published_at: null,
            min_price: null,
            max_price: null,
            active_variant_count: 0,
            total_variant_count: 0,
            stock_state: "out_of_stock",
            filtered_count: 2,
          }),
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

    expect(calls.find((call) => call.type === "rpc")?.args).toEqual(
      expect.objectContaining({
        p_stock: "out_of_stock",
        p_sort: "price_desc",
        p_offset: 0,
        p_limit: PRODUCT_PAGE_SIZE_DEFAULT,
      }),
    );
    expect(listed.ok).toBe(true);
    if (listed.ok) {
      expect(listed.result.items.map((item) => item.id)).toEqual([
        PRODUCT_ID,
        PRODUCT_ID_B,
      ]);
      expect(listed.result.items[0]?.priceRange.minAmount).toBe("50.00");
      expect(listed.result.items[1]?.priceRange.minAmount).toBeNull();
      expect(listed.result.totalCount).toBe(2);
    }

    const inStock = await listProducts({
      supabase: createExplorerClient([], {
        rpcRows: [{ id: null, filtered_count: 0 }],
        images: [],
        categories: [],
        brands: [],
      }),
      query: defaultQuery({ stock: "in_stock" }),
      supabaseUrl: "https://example.supabase.co",
    });

    expect(inStock.ok).toBe(true);
    if (inStock.ok) {
      expect(inStock.result.items).toEqual([]);
      expect(inStock.result.totalCount).toBe(0);
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
        rpcRows: [{ id: "bad-row", boom: "sql token=secret" }],
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

function rpcExplorerRow(
  overrides: Record<string, unknown> = {},
): Record<string, unknown> {
  return {
    id: PRODUCT_ID,
    category_id: CATEGORY_ID,
    brand_id: null,
    name: "Aero Strike",
    slug: "aero-strike",
    status: "active",
    is_featured: false,
    published_at: "2026-01-01T00:00:00.000Z",
    updated_at: "2026-01-02T00:00:00.000Z",
    active_variant_count: 1,
    total_variant_count: 1,
    min_price: "1890000.00",
    max_price: "1890000.00",
    total_on_hand: 4,
    total_reserved: 1,
    total_available: 3,
    missing_inventory_count: 0,
    has_missing_inventory: false,
    is_low_stock: false,
    stock_state: "in_stock",
    filtered_count: 1,
    ...overrides,
  };
}

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
    rpcRows?: unknown[];
    rpcError?: unknown;
    images?: unknown[];
    categories?: unknown[];
    brands?: unknown[];
  },
) {
  return {
    auth: {
      getClaims: async () => ({ data: { claims: null }, error: null }),
    },
    rpc(fn: string, args: unknown) {
      calls.push({ type: "rpc", fn, args });
      if (fixtures.rpcError) {
        return Promise.resolve({ data: null, error: fixtures.rpcError });
      }
      return Promise.resolve({
        data: fixtures.rpcRows ?? [],
        error: null,
      });
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
          return Promise.resolve({ data: [], error: null, count: 0 });
        },
        limit(count: number) {
          state.limit = count;
          calls.push({ ...state });
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
