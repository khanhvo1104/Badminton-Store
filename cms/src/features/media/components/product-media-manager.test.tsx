import { render, screen } from "@testing-library/react";
import { describe, expect, it, vi } from "vitest";

import { ProductMediaManager } from "@/features/media/components/product-media-manager";
import type { ProductMediaImage } from "@/features/media/types";

vi.mock("next/navigation", () => ({
  useRouter: () => ({ refresh: vi.fn() }),
}));

const PRODUCT_ID = "30000000-0000-4000-8000-000000000001";
const IMAGE_ID = "50000000-0000-4000-8000-000000000001";

const image: ProductMediaImage = {
  id: IMAGE_ID,
  productId: PRODUCT_ID,
  variantId: null,
  variantLabel: null,
  storagePath: `product-images/${PRODUCT_ID}/main.webp`,
  previewUrl: `https://example.supabase.co/storage/v1/object/public/product-images/${PRODUCT_ID}/main.webp`,
  altText: "Main racket",
  sortOrder: 0,
  isPrimary: true,
  scopeLabel: "Product gallery",
  primaryLabel: "Primary",
  updatedAt: "2026-08-19T00:00:00.000Z",
};

describe("ProductMediaManager", () => {
  it("renders public raster previews and hides cost or barcode", () => {
    render(
      <ProductMediaManager
        productId={PRODUCT_ID}
        images={[image]}
        variants={[
          {
            id: "40000000-0000-4000-8000-000000000001",
            sku: "SKU-1",
            name: "Red",
            label: "SKU-1 — Red",
          },
        ]}
      />,
    );

    const preview = screen.getByAltText("Main racket");
    expect(preview.getAttribute("src")).toContain(
      `/storage/v1/object/public/product-images/${PRODUCT_ID}/main.webp`,
    );
    expect(preview.tagName).toBe("IMG");
    expect(preview.getAttribute("src")).not.toMatch(/\.svg(?:$|[?#])/i);
    expect(screen.getByText("Primary")).toBeTruthy();
    expect(screen.getByLabelText("Image file")).toBeTruthy();
    expect(screen.getByText(/Never upload SVG/i)).toBeTruthy();
    expect(screen.queryByText(/barcode|cost_price/i)).toBeNull();
  });

  it("shows an empty state when the product has no images", () => {
    render(
      <ProductMediaManager productId={PRODUCT_ID} images={[]} variants={[]} />,
    );
    expect(screen.getByText("No images yet")).toBeTruthy();
  });
});
