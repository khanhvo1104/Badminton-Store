import type { ReactNode } from "react";
import { render, screen } from "@testing-library/react";
import { beforeEach, describe, expect, it, vi } from "vitest";

const createSupabaseServerClient = vi.hoisted(() => vi.fn());
const listProductVariants = vi.hoisted(() => vi.fn());

vi.mock("@/lib/supabase/server", () => ({ createSupabaseServerClient }));
vi.mock("@/features/variants/queries", async () => {
  const actual = await vi.importActual<
    typeof import("@/features/variants/queries")
  >("@/features/variants/queries");
  return { ...actual, listProductVariants };
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

const PRODUCT_ID = "30000000-0000-4000-8000-000000001001";

describe("ProductVariantsPage", () => {
  beforeEach(() => {
    createSupabaseServerClient.mockReset();
    listProductVariants.mockReset();
    createSupabaseServerClient.mockResolvedValue({});
  });

  it("renders variants and hides barcode", async () => {
    listProductVariants.mockResolvedValue({
      ok: true,
      data: {
        productId: PRODUCT_ID,
        productName: "Aero Strike",
        isFirstVariant: false,
        variants: [
          {
            id: "40000000-0000-4000-8000-000000000001",
            productId: PRODUCT_ID,
            sku: "RKT-1",
            name: "Red",
            statusLabel: "Active",
            defaultLabel: "Default",
            isDefault: true,
            isActive: true,
            attributesLabel: "None",
            price: "10.00",
            priceLabel: "10₫",
            compareAtPrice: null,
            compareAtPriceLabel: "None",
            costPrice: null,
            costPriceLabel: "Not recorded",
            unit: "item",
            sortOrder: 0,
            colorName: null,
            colorHex: null,
            racketWeightClass: null,
            gripSize: null,
            shoeSize: null,
            clothingSize: null,
            attributes: {},
          },
        ],
      },
    });

    const Page = (await import("./page")).default;
    const ui = await Page({
      params: Promise.resolve({ productId: PRODUCT_ID }),
    });
    render(ui);

    expect(screen.getByText("Variants for Aero Strike")).toBeTruthy();
    expect(screen.getAllByText("RKT-1").length).toBeGreaterThan(0);
    expect(screen.getAllByText("Not recorded").length).toBeGreaterThan(0);
    expect(screen.queryByText(/barcode/i)).toBeNull();
    expect(
      screen.getByRole("link", { name: "Add variant" }).getAttribute("href"),
    ).toBe(`/dashboard/products/${PRODUCT_ID}/variants/new`);
  });

  it("uses not-found for an invalid product id", async () => {
    const Page = (await import("./page")).default;
    await expect(
      Page({ params: Promise.resolve({ productId: "not-a-uuid" }) }),
    ).rejects.toThrow("NEXT_NOT_FOUND");
    expect(listProductVariants).not.toHaveBeenCalled();
  });
});
