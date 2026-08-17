import type { ReactNode } from "react";
import { render, screen } from "@testing-library/react";
import { beforeEach, describe, expect, it, vi } from "vitest";

const createSupabaseServerClient = vi.hoisted(() => vi.fn());
const getPublicEnvironment = vi.hoisted(() => vi.fn());
const listBrands = vi.hoisted(() => vi.fn());

vi.mock("@/lib/supabase/server", () => ({ createSupabaseServerClient }));
vi.mock("@/lib/env/public-env", () => ({ getPublicEnvironment }));
vi.mock("@/features/brands/queries", async () => {
  const actual = await vi.importActual<
    typeof import("@/features/brands/queries")
  >("@/features/brands/queries");
  return { ...actual, listBrands };
});
vi.mock("next/link", () => ({
  default: ({ href, children }: { href: string; children: ReactNode }) => (
    <a href={href}>{children}</a>
  ),
}));

describe("BrandsPage", () => {
  beforeEach(() => {
    createSupabaseServerClient.mockReset();
    getPublicEnvironment.mockReset();
    listBrands.mockReset();
    getPublicEnvironment.mockReturnValue({
      supabaseUrl: "https://example.supabase.co",
      supabasePublishableKey: "publishable",
    });
    createSupabaseServerClient.mockResolvedValue({});
  });

  it("renders list success and sanitized error states", async () => {
    listBrands.mockResolvedValue({
      ok: true,
      result: {
        items: [
          {
            id: "20000000-0000-4000-8000-000000000001",
            name: "Yonex",
            slug: "yonex",
            description: null,
            logoPath: null,
            logoUrl: null,
            websiteUrl: "https://www.yonex.com",
            countryOfOrigin: "Japan",
            sortOrder: 10,
            isActive: false,
          },
        ],
        totalCount: 1,
        totalPages: 1,
        pagination: { page: 1, pageSize: 20, from: 0, to: 19 },
      },
    });

    const { default: BrandsPage } = await import("@/app/dashboard/brands/page");
    render(
      await BrandsPage({
        searchParams: Promise.resolve({ success: "created" }),
      }),
    );
    expect(
      screen.getByRole("heading", { name: "Brand management" }),
    ).toBeInTheDocument();
    expect(screen.getByText("Brand created.")).toBeInTheDocument();
    expect(screen.getByText("Yonex")).toBeInTheDocument();
    expect(screen.getByText("Japan")).toBeInTheDocument();
    expect(screen.getByText("Inactive")).toBeInTheDocument();
    expect(screen.getByRole("link", { name: "Edit" })).toHaveAttribute(
      "href",
      "/dashboard/brands/20000000-0000-4000-8000-000000000001/edit",
    );

    listBrands.mockResolvedValue({
      ok: false,
      message: "We couldn't save that brand. Check your input and try again.",
    });
    render(await BrandsPage({ searchParams: Promise.resolve({}) }));
    expect(screen.getByText("Brands unavailable")).toBeInTheDocument();
    expect(screen.queryByText("provider boom")).not.toBeInTheDocument();
  });

  it("renders the empty state for an authorized empty catalog", async () => {
    listBrands.mockResolvedValue({
      ok: true,
      result: {
        items: [],
        totalCount: 0,
        totalPages: 0,
        pagination: { page: 1, pageSize: 20, from: 0, to: 19 },
      },
    });

    const { default: BrandsPage } = await import("@/app/dashboard/brands/page");
    render(await BrandsPage({ searchParams: Promise.resolve({}) }));
    expect(
      screen.getByRole("heading", { name: "No brands yet" }),
    ).toBeInTheDocument();
    expect(screen.getByRole("link", { name: "Create brand" })).toHaveAttribute(
      "href",
      "/dashboard/brands/new",
    );
  });
});
