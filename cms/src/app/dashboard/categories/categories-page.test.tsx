import type { ReactNode } from "react";
import { render, screen } from "@testing-library/react";
import { beforeEach, describe, expect, it, vi } from "vitest";

const createSupabaseServerClient = vi.hoisted(() => vi.fn());
const getPublicEnvironment = vi.hoisted(() => vi.fn());
const listCategories = vi.hoisted(() => vi.fn());

vi.mock("@/lib/supabase/server", () => ({ createSupabaseServerClient }));
vi.mock("@/lib/env/public-env", () => ({ getPublicEnvironment }));
vi.mock("@/features/categories/queries", async () => {
  const actual = await vi.importActual<
    typeof import("@/features/categories/queries")
  >("@/features/categories/queries");
  return { ...actual, listCategories };
});
vi.mock("next/link", () => ({
  default: ({ href, children }: { href: string; children: ReactNode }) => (
    <a href={href}>{children}</a>
  ),
}));

describe("CategoriesPage", () => {
  beforeEach(() => {
    createSupabaseServerClient.mockReset();
    getPublicEnvironment.mockReset();
    listCategories.mockReset();
    getPublicEnvironment.mockReturnValue({
      supabaseUrl: "https://example.supabase.co",
      supabasePublishableKey: "publishable",
    });
    createSupabaseServerClient.mockResolvedValue({});
  });

  it("renders list success and sanitized error states", async () => {
    listCategories.mockResolvedValue({
      ok: true,
      result: {
        items: [
          {
            id: "10000000-0000-4000-8000-000000000001",
            parentId: null,
            parentName: null,
            name: "Rackets",
            slug: "rackets",
            description: null,
            imagePath: null,
            imageUrl: null,
            sortOrder: 10,
            isActive: true,
          },
        ],
        totalCount: 1,
        totalPages: 1,
        pagination: { page: 1, pageSize: 20, from: 0, to: 19 },
      },
    });

    const { default: CategoriesPage } = await import(
      "@/app/dashboard/categories/page"
    );
    render(
      await CategoriesPage({
        searchParams: Promise.resolve({ success: "created" }),
      }),
    );
    expect(
      screen.getByRole("heading", { name: "Category management" }),
    ).toBeInTheDocument();
    expect(screen.getByText("Category created.")).toBeInTheDocument();
    expect(screen.getByText("Rackets")).toBeInTheDocument();

    listCategories.mockResolvedValue({
      ok: false,
      message:
        "We couldn't save that category. Check your input and try again.",
    });
    render(await CategoriesPage({ searchParams: Promise.resolve({}) }));
    expect(screen.getByText("Categories unavailable")).toBeInTheDocument();
    expect(screen.queryByText("provider boom")).not.toBeInTheDocument();
  });
});
