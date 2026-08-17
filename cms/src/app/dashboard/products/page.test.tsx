import { beforeEach, describe, expect, it, vi } from "vitest";

const createSupabaseServerClient = vi.hoisted(() => vi.fn());
const getPublicEnvironment = vi.hoisted(() => vi.fn());
const authorizeCmsRequest = vi.hoisted(() => vi.fn());
const listProducts = vi.hoisted(() => vi.fn());
const listProductCategoryOptions = vi.hoisted(() => vi.fn());
const listProductBrandOptions = vi.hoisted(() => vi.fn());

vi.mock("@/lib/supabase/server", () => ({
  createSupabaseServerClient,
}));
vi.mock("@/lib/env/public-env", () => ({
  getPublicEnvironment,
}));
vi.mock("@/lib/auth/authorization", async () => {
  const actual = await vi.importActual<
    typeof import("@/lib/auth/authorization")
  >("@/lib/auth/authorization");
  return { ...actual, authorizeCmsRequest };
});
vi.mock("@/features/products/queries", () => ({
  listProducts,
  listProductCategoryOptions,
  listProductBrandOptions,
}));

describe("Products page", () => {
  beforeEach(() => {
    createSupabaseServerClient.mockReset();
    getPublicEnvironment.mockReset();
    authorizeCmsRequest.mockReset();
    listProducts.mockReset();
    listProductCategoryOptions.mockReset();
    listProductBrandOptions.mockReset();
  });

  it("loads an explicitly ordered page through the SSR client", async () => {
    getPublicEnvironment.mockReturnValue({
      supabaseUrl: "https://example.supabase.co",
      supabasePublishableKey: "publishable",
    });
    createSupabaseServerClient.mockResolvedValue({ tagged: "ssr-client" });
    authorizeCmsRequest.mockResolvedValue({
      kind: "authorized",
      profile: {
        id: "staff-1",
        fullName: "Alex Coach",
        role: "staff",
        isActive: true,
      },
    });
    listProducts.mockResolvedValue({
      ok: true,
      result: {
        items: [],
        totalCount: 0,
        pagination: { page: 1, pageSize: 20, from: 0, to: 19 },
        totalPages: 0,
        hasActiveFilters: false,
        query: {
          search: "",
          categoryId: null,
          brandId: null,
          status: null,
          stock: "all",
          sort: "updated_desc",
          pagination: { page: 1, pageSize: 20, from: 0, to: 19 },
        },
      },
    });
    listProductCategoryOptions.mockResolvedValue({ ok: true, options: [] });
    listProductBrandOptions.mockResolvedValue({ ok: true, options: [] });

    const { default: ProductsPage } = await import(
      "@/app/dashboard/products/page"
    );
    const element = await ProductsPage({
      searchParams: Promise.resolve({ page: "1" }),
    });

    expect(listProducts).toHaveBeenCalledWith(
      expect.objectContaining({
        supabase: { tagged: "ssr-client" },
        supabaseUrl: "https://example.supabase.co",
        query: expect.objectContaining({
          pagination: { page: 1, pageSize: 20, from: 0, to: 19 },
          sort: "updated_desc",
        }),
      }),
    );
    expect(element).toBeTruthy();
  });
});
