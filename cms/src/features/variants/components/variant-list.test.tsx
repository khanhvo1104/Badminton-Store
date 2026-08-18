import { render, screen } from "@testing-library/react";
import { describe, expect, it, vi } from "vitest";

import { VariantList } from "@/features/variants/components/variant-list";
import type { VariantListItem } from "@/features/variants/types";

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

const PRODUCT_ID = "30000000-0000-4000-8000-000000000001";
const VARIANT_ID = "40000000-0000-4000-8000-000000000001";

const item: VariantListItem = {
  id: VARIANT_ID,
  productId: PRODUCT_ID,
  sku: "SKU-1",
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
  costPrice: "0.00",
  costPriceLabel: "0₫",
  unit: "item",
  sortOrder: 1,
  colorName: null,
  colorHex: null,
  racketWeightClass: null,
  gripSize: null,
  shoeSize: null,
  clothingSize: null,
  attributes: {},
};

describe("VariantList", () => {
  it("shows status, prices, cost, and edit link without barcode", () => {
    render(<VariantList productId={PRODUCT_ID} variants={[item]} />);
    expect(screen.getAllByText("SKU-1").length).toBeGreaterThan(0);
    expect(screen.getAllByText("Active").length).toBeGreaterThan(0);
    expect(screen.getAllByText("Default").length).toBeGreaterThan(0);
    expect(screen.getAllByText("0₫").length).toBeGreaterThan(0);
    expect(screen.queryByText(/barcode/i)).toBeNull();
    expect(
      screen.getAllByRole("link", { name: "Edit variant SKU-1" })[0],
    ).toHaveAttribute(
      "href",
      `/dashboard/products/${PRODUCT_ID}/variants/${VARIANT_ID}/edit`,
    );
  });

  it("renders an empty state", () => {
    render(<VariantList productId={PRODUCT_ID} variants={[]} />);
    expect(screen.getByText("No variants yet")).toBeTruthy();
  });
});
