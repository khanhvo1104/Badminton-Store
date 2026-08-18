import { render, screen } from "@testing-library/react";
import { describe, expect, it, vi } from "vitest";

import { InventoryList } from "@/features/inventory/components/inventory-list";
import type {
  InventoryListItem,
  InventoryListResult,
} from "@/features/inventory/types";

vi.mock("next/link", () => ({
  default: ({
    href,
    children,
    ...props
  }: {
    href: string;
    children: React.ReactNode;
    [key: string]: unknown;
  }) => (
    <a href={href} {...props}>
      {children}
    </a>
  ),
}));

const VARIANT_ID = "40000000-0000-4000-8000-000000000001";

const item: InventoryListItem = {
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
};

function result(items: InventoryListItem[]): InventoryListResult {
  return {
    items,
    totalCount: items.length,
    pagination: { page: 1, pageSize: 20, from: 0, to: 19 },
    totalPages: 1,
    hasActiveFilters: false,
    query: {
      search: "",
      stock: "all",
      sort: "updated_desc",
      pagination: { page: 1, pageSize: 20, from: 0, to: 19 },
    },
  };
}

describe("InventoryList", () => {
  it("shows stock columns and an adjust link without cost or barcode", () => {
    render(<InventoryList result={result([item])} />);
    expect(screen.getAllByText("Aero Strike").length).toBeGreaterThan(0);
    expect(screen.getAllByText("SKU-1").length).toBeGreaterThan(0);
    expect(screen.getAllByText("On hand").length).toBeGreaterThan(0);
    expect(screen.queryByText(/cost_price|barcode/i)).toBeNull();
    expect(
      screen.getAllByRole("link", { name: "Adjust inventory for SKU-1" })[0],
    ).toHaveAttribute("href", `/dashboard/inventory/${VARIANT_ID}`);
  });

  it("renders an empty state", () => {
    render(<InventoryList result={result([])} />);
    expect(screen.getByText("No variants yet")).toBeTruthy();
  });
});
