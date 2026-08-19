import type { ReactNode } from "react";
import { render, screen } from "@testing-library/react";
import { beforeEach, describe, expect, it, vi } from "vitest";

const createSupabaseServerClient = vi.hoisted(() => vi.fn());
const getPublicEnvironment = vi.hoisted(() => vi.fn());
const getProductMediaPage = vi.hoisted(() => vi.fn());

vi.mock("@/lib/supabase/server", () => ({ createSupabaseServerClient }));
vi.mock("@/lib/env/public-env", () => ({ getPublicEnvironment }));
vi.mock("@/features/media/queries", async () => {
  const actual = await vi.importActual<
    typeof import("@/features/media/queries")
  >("@/features/media/queries");
  return { ...actual, getProductMediaPage };
});
vi.mock("next/link", () => ({
  default: ({ href, children }: { href: string; children: ReactNode }) => (
    <a href={href}>{children}</a>
  ),
}));
vi.mock("next/navigation", () => ({
  notFound: () => {
    throw new Error("NEXT_NOT_FOUND");
  },
}));

const PRODUCT_ID = "30000000-0000-4000-8000-000000000001";

describe("ProductMediaPage", () => {
  beforeEach(() => {
    createSupabaseServerClient.mockReset();
    getPublicEnvironment.mockReset();
    getProductMediaPage.mockReset();
    createSupabaseServerClient.mockResolvedValue({});
    getPublicEnvironment.mockReturnValue({
      supabaseUrl: "https://example.supabase.co",
      supabasePublishableKey: "publishable",
    });
  });

  it("renders images without barcode or cost", async () => {
    getProductMediaPage.mockResolvedValue({
      ok: true,
      data: {
        productId: PRODUCT_ID,
        productName: "Aero Strike",
        variants: [],
        images: [
          {
            id: "50000000-0000-4000-8000-000000000001",
            productId: PRODUCT_ID,
            variantId: null,
            variantLabel: null,
            storagePath: `product-images/${PRODUCT_ID}/main.webp`,
            previewUrl: `https://example.supabase.co/storage/v1/object/public/product-images/${PRODUCT_ID}/main.webp`,
            altText: "Main",
            sortOrder: 0,
            isPrimary: true,
            scopeLabel: "Product gallery",
            primaryLabel: "Primary",
            updatedAt: "2026-08-19T00:00:00.000Z",
          },
        ],
      },
    });

    const Page = (await import("./page")).default;
    const ui = await Page({
      params: Promise.resolve({ productId: PRODUCT_ID }),
    });
    render(ui);

    expect(screen.getByText("Media for Aero Strike")).toBeTruthy();
    expect(screen.getByAltText("Main")).toBeTruthy();
    expect(screen.queryByText(/barcode|cost_price/i)).toBeNull();
  });

  it("uses not-found for an invalid product id", async () => {
    const Page = (await import("./page")).default;
    await expect(
      Page({ params: Promise.resolve({ productId: "not-a-uuid" }) }),
    ).rejects.toThrow("NEXT_NOT_FOUND");
    expect(getProductMediaPage).not.toHaveBeenCalled();
  });
});
