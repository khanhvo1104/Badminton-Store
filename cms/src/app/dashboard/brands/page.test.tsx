import { beforeEach, describe, expect, it, vi } from "vitest";

const createSupabaseServerClient = vi.hoisted(() => vi.fn());
const getPublicEnvironment = vi.hoisted(() => vi.fn());
const listBrands = vi.hoisted(() => vi.fn());

vi.mock("@/lib/supabase/server", () => ({
  createSupabaseServerClient,
}));

vi.mock("@/lib/env/public-env", () => ({
  getPublicEnvironment,
}));

vi.mock("@/features/brands/queries", () => ({
  listBrands,
}));

describe("Brands page", () => {
  beforeEach(() => {
    createSupabaseServerClient.mockReset();
    getPublicEnvironment.mockReset();
    listBrands.mockReset();
  });

  it("loads an explicitly ordered page through the SSR client", async () => {
    getPublicEnvironment.mockReturnValue({
      supabaseUrl: "https://example.supabase.co",
      supabasePublishableKey: "publishable",
    });
    createSupabaseServerClient.mockResolvedValue({ tagged: "ssr-client" });
    listBrands.mockResolvedValue({
      ok: true,
      result: {
        items: [],
        totalCount: 0,
        pagination: { page: 1, pageSize: 20, from: 0, to: 19 },
        totalPages: 0,
      },
    });

    const { default: BrandsPage } = await import("@/app/dashboard/brands/page");
    const element = await BrandsPage({
      searchParams: Promise.resolve({ page: "1", pageSize: "20" }),
    });

    expect(listBrands).toHaveBeenCalledWith(
      expect.objectContaining({
        supabase: { tagged: "ssr-client" },
        pagination: { page: 1, pageSize: 20, from: 0, to: 19 },
        supabaseUrl: "https://example.supabase.co",
      }),
    );
    expect(element).toBeTruthy();
  });
});
