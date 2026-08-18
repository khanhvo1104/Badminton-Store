import type { ReactNode } from "react";
import { fireEvent, render, screen } from "@testing-library/react";
import { beforeEach, describe, expect, it, vi } from "vitest";

const createSupabaseServerClient = vi.hoisted(() => vi.fn());
const getPublicEnvironment = vi.hoisted(() => vi.fn());
const authorizeCmsRequest = vi.hoisted(() => vi.fn());
const listProducts = vi.hoisted(() => vi.fn());
const listProductCategoryOptions = vi.hoisted(() => vi.fn());
const listProductBrandOptions = vi.hoisted(() => vi.fn());

vi.mock("@/lib/supabase/server", () => ({ createSupabaseServerClient }));
vi.mock("@/lib/env/public-env", () => ({ getPublicEnvironment }));
vi.mock("@/lib/auth/authorization", async () => {
  const actual = await vi.importActual<
    typeof import("@/lib/auth/authorization")
  >("@/lib/auth/authorization");
  return { ...actual, authorizeCmsRequest };
});
vi.mock("@/features/products/queries", async () => {
  const actual = await vi.importActual<
    typeof import("@/features/products/queries")
  >("@/features/products/queries");
  return {
    ...actual,
    listProducts,
    listProductCategoryOptions,
    listProductBrandOptions,
  };
});
vi.mock("next/link", () => ({
  default: ({ href, children }: { href: string; children: ReactNode }) => (
    <a href={href}>{children}</a>
  ),
}));
vi.mock("next/navigation", () => ({
  useRouter: () => ({ refresh: vi.fn() }),
}));

const PRODUCT_ID = "30000000-0000-4000-8000-000000000001";

describe("ProductsPage", () => {
  beforeEach(() => {
    createSupabaseServerClient.mockReset();
    getPublicEnvironment.mockReset();
    authorizeCmsRequest.mockReset();
    listProducts.mockReset();
    listProductCategoryOptions.mockReset();
    listProductBrandOptions.mockReset();
    getPublicEnvironment.mockReturnValue({
      supabaseUrl: "https://example.supabase.co",
      supabasePublishableKey: "publishable",
    });
    createSupabaseServerClient.mockResolvedValue({});
    authorizeCmsRequest.mockResolvedValue({
      kind: "authorized",
      profile: {
        id: "staff-1",
        fullName: "Alex Coach",
        role: "staff",
        isActive: true,
      },
    });
    listProductCategoryOptions.mockResolvedValue({
      ok: true,
      options: [
        {
          id: "10000000-0000-4000-8000-000000000001",
          name: "Rackets",
          isActive: true,
        },
      ],
    });
    listProductBrandOptions.mockResolvedValue({
      ok: true,
      options: [
        {
          id: "20000000-0000-4000-8000-000000000001",
          name: "Yonex",
          isActive: false,
        },
      ],
    });
  });

  it("renders populated, filtered-empty, and sanitized error states", async () => {
    listProducts.mockResolvedValue({
      ok: true,
      result: {
        items: [
          {
            id: PRODUCT_ID,
            name: "Aero Strike",
            slug: "aero-strike",
            categoryId: "10000000-0000-4000-8000-000000000001",
            categoryName: "Rackets",
            brandId: "20000000-0000-4000-8000-000000000001",
            brandName: "Yonex",
            status: "draft",
            statusLabel: "Draft",
            isFeatured: true,
            featuredLabel: "Featured",
            publishedAt: null,
            publishedAtLabel: "Not published",
            updatedAt: "2026-01-02T00:00:00.000Z",
            updatedAtLabel: "2 Jan 2026, 00:00",
            primaryImageUrl: null,
            activeVariantCount: 1,
            totalVariantCount: 2,
            priceRange: {
              minAmount: "0",
              maxAmount: "0",
              label: "0₫",
            },
            inventory: {
              totalOnHand: 0,
              totalReserved: 0,
              totalAvailable: 0,
              missingInventoryCount: 0,
              hasMissingInventory: false,
              isLowStock: true,
              stockState: "out_of_stock",
              stockLabel: "Out of stock",
            },
          },
        ],
        totalCount: 1,
        totalPages: 1,
        hasActiveFilters: false,
        pagination: { page: 1, pageSize: 20, from: 0, to: 19 },
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

    const { default: ProductsPage } = await import(
      "@/app/dashboard/products/page"
    );
    render(await ProductsPage({ searchParams: Promise.resolve({}) }));

    expect(
      screen.getByRole("heading", { name: "Product explorer" }),
    ).toBeInTheDocument();
    expect(screen.getAllByText("Aero Strike").length).toBeGreaterThan(0);
    expect(screen.getAllByText("Draft").length).toBeGreaterThan(0);
    expect(screen.getAllByText("Featured").length).toBeGreaterThan(0);
    expect(screen.getAllByText("Out of stock").length).toBeGreaterThan(0);
    expect(screen.getAllByText("0₫").length).toBeGreaterThan(0);
    expect(screen.getByText("Yonex (inactive)")).toBeInTheDocument();
    expect(
      screen.getByRole("button", { name: "Apply filters" }),
    ).toBeInTheDocument();
    expect(screen.getByRole("link", { name: "Clear filters" })).toHaveAttribute(
      "href",
      "/dashboard/products",
    );
    expect(screen.getByRole("link", { name: "New product" })).toHaveAttribute(
      "href",
      "/dashboard/products/new",
    );
    expect(screen.getAllByRole("link", { name: "View" })[0]).toHaveAttribute(
      "href",
      `/dashboard/products/${PRODUCT_ID}`,
    );
    expect(screen.getAllByRole("link", { name: "Edit" })[0]).toHaveAttribute(
      "href",
      `/dashboard/products/${PRODUCT_ID}/edit`,
    );

    listProducts.mockResolvedValue({
      ok: true,
      result: {
        items: [],
        totalCount: 0,
        totalPages: 0,
        hasActiveFilters: true,
        pagination: { page: 1, pageSize: 20, from: 0, to: 19 },
        query: {
          search: "missing",
          categoryId: null,
          brandId: null,
          status: null,
          stock: "all",
          sort: "updated_desc",
          pagination: { page: 1, pageSize: 20, from: 0, to: 19 },
        },
      },
    });
    render(
      await ProductsPage({
        searchParams: Promise.resolve({ q: "missing" }),
      }),
    );
    expect(
      screen.getByRole("heading", { name: "No products match these filters" }),
    ).toBeInTheDocument();

    listProducts.mockResolvedValue({
      ok: false,
      message: "We couldn't load products right now. Try again in a moment.",
    });
    render(await ProductsPage({ searchParams: Promise.resolve({}) }));
    expect(screen.getByText("Products unavailable")).toBeInTheDocument();
    expect(screen.queryByText("provider boom")).not.toBeInTheDocument();
  });

  it("does not list products before authorization succeeds", async () => {
    authorizeCmsRequest.mockResolvedValue({ kind: "unauthorized" });
    const { default: ProductsPage } = await import(
      "@/app/dashboard/products/page"
    );
    render(await ProductsPage({ searchParams: Promise.resolve({}) }));
    expect(listProducts).not.toHaveBeenCalled();
    expect(
      screen.getByText("You do not have permission to view products."),
    ).toBeInTheDocument();
  });
});

describe("products loading and error routes", () => {
  it("renders the products loading skeleton", async () => {
    const { default: ProductsLoading } = await import(
      "@/app/dashboard/products/loading"
    );

    render(<ProductsLoading />);
    expect(
      screen.getByRole("status", { name: "Loading products" }),
    ).toBeInTheDocument();
  });

  it("retries through the error boundary reset callback", async () => {
    const reset = vi.fn();
    const consoleError = vi
      .spyOn(console, "error")
      .mockImplementation(() => undefined);

    const { default: ProductsError } = await import(
      "@/app/dashboard/products/error"
    );

    render(
      <ProductsError
        error={new Error("internal sql token=secret")}
        reset={reset}
      />,
    );

    expect(
      screen.getByRole("heading", { name: "Products unavailable" }),
    ).toBeInTheDocument();
    expect(screen.queryByText(/sql|token=secret/i)).not.toBeInTheDocument();

    fireEvent.click(screen.getByRole("button", { name: "Try again" }));
    expect(reset).toHaveBeenCalledTimes(1);

    consoleError.mockRestore();
  });
});
