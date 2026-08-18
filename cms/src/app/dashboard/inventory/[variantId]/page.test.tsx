import type { ReactNode } from "react";
import { render, screen } from "@testing-library/react";
import { beforeEach, describe, expect, it, vi } from "vitest";

const createSupabaseServerClient = vi.hoisted(() => vi.fn());
const getInventoryVariant = vi.hoisted(() => vi.fn());

vi.mock("@/lib/supabase/server", () => ({ createSupabaseServerClient }));
vi.mock("@/features/inventory/queries", async () => {
  const actual = await vi.importActual<
    typeof import("@/features/inventory/queries")
  >("@/features/inventory/queries");
  return { ...actual, getInventoryVariant };
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
vi.mock("@/features/inventory/actions/adjust-inventory", () => ({
  adjustInventory: vi.fn(),
}));
vi.mock("react", async () => {
  const actual = await vi.importActual<typeof import("react")>("react");
  return {
    ...actual,
    useActionState: (_action: unknown, initialState: unknown) => [
      initialState,
      vi.fn(),
    ],
  };
});
vi.mock("react-dom", async () => {
  const actual = await vi.importActual<typeof import("react-dom")>("react-dom");
  return {
    ...actual,
    useFormStatus: () => ({ pending: false }),
  };
});

const VARIANT_ID = "40000000-0000-4000-8000-000000000001";

describe("InventoryAdjustmentPage", () => {
  beforeEach(() => {
    createSupabaseServerClient.mockReset();
    getInventoryVariant.mockReset();
    createSupabaseServerClient.mockResolvedValue({});
  });

  it("renders current stock and hides reserved editing", async () => {
    getInventoryVariant.mockResolvedValue({
      ok: true,
      detail: {
        variantId: VARIANT_ID,
        productId: "30000000-0000-4000-8000-000000000001",
        productName: "Aero Strike",
        variantName: "Red",
        sku: "SKU-1",
        quantityOnHand: 10,
        quantityReserved: 2,
        quantityAvailable: 8,
        reorderLevel: 4,
        allowBackorder: false,
        allowBackorderLabel: "No",
        stockState: "in_stock",
        stockLabel: "In stock",
        updatedAt: "2026-08-18T00:00:00.000Z",
        updatedAtLabel: "18 Aug 2026, 00:00",
        hasInventoryRow: true,
        history: [],
      },
    });

    const Page = (await import("./page")).default;
    const ui = await Page({
      params: Promise.resolve({ variantId: VARIANT_ID }),
      searchParams: Promise.resolve({ success: "adjusted" }),
    });
    render(ui);

    expect(screen.getByText("Adjust inventory")).toBeTruthy();
    expect(screen.getByText("Inventory adjusted.")).toBeTruthy();
    expect(screen.getAllByText(/SKU-1/).length).toBeGreaterThan(0);
    expect(screen.queryByLabelText(/reserved/i)).toBeNull();
    expect(screen.queryByText(/cost_price|barcode/i)).toBeNull();
  });

  it("not-founds an invalid route id without loading inventory", async () => {
    const Page = (await import("./page")).default;
    await expect(
      Page({
        params: Promise.resolve({ variantId: "not-a-uuid" }),
      }),
    ).rejects.toThrow("NEXT_NOT_FOUND");
    expect(getInventoryVariant).not.toHaveBeenCalled();
  });
});
