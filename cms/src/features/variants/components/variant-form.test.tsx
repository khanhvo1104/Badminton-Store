import { render, screen } from "@testing-library/react";
import { describe, expect, it, vi } from "vitest";

import { VariantForm } from "@/features/variants/components/variant-form";
import { INITIAL_VARIANT_FORM_STATE } from "@/features/variants/variant-form-state";

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
    useFormStatus: () => ({
      pending: false,
      data: null,
      method: null,
      action: null,
    }),
  };
});

vi.mock("@/features/variants/actions/create-variant", () => ({
  createVariant: vi.fn(),
}));

vi.mock("@/features/variants/actions/update-variant", () => ({
  updateVariant: vi.fn(),
}));

const PRODUCT_ID = "30000000-0000-4000-8000-000000000001";

describe("VariantForm", () => {
  it("exposes accessible labels for create", () => {
    render(
      <VariantForm
        mode="create"
        productId={PRODUCT_ID}
        initialState={INITIAL_VARIANT_FORM_STATE}
      />,
    );

    expect(screen.getByLabelText("SKU")).toBeTruthy();
    expect(screen.getByLabelText("Name")).toBeTruthy();
    expect(screen.getByLabelText("Color hex")).toBeTruthy();
    expect(screen.getByLabelText("Selling price")).toBeTruthy();
    expect(screen.getByLabelText("Compare-at price")).toBeTruthy();
    expect(screen.getByLabelText("Protected cost")).toBeTruthy();
    expect(screen.getByLabelText("Barcode")).toBeTruthy();
    expect(screen.getByLabelText("Default variant")).toBeTruthy();
    expect(screen.getByRole("button", { name: "Create variant" })).toBeTruthy();
    expect(
      document.querySelector('input[type="hidden"][name="product_id"]'),
    ).toBeNull();
  });

  it("documents barcode preserve UX on edit and does not submit ids", () => {
    render(
      <VariantForm
        mode="edit"
        productId={PRODUCT_ID}
        variantId="40000000-0000-4000-8000-000000000001"
        currentIsDefault
        initialState={INITIAL_VARIANT_FORM_STATE}
      />,
    );

    expect(
      screen.getByText(/Leave blank to keep the existing barcode/i),
    ).toBeTruthy();
    expect(screen.getByLabelText("Clear barcode")).toBeTruthy();
    expect(
      document.querySelector('input[type="hidden"][name="id"]'),
    ).toBeNull();
    expect(
      document.querySelector('input[type="hidden"][name="variant_id"]'),
    ).toBeNull();
  });

  it("associates help and error IDs", () => {
    render(
      <VariantForm
        mode="create"
        productId={PRODUCT_ID}
        initialState={{
          status: "error",
          message: "Fix the highlighted fields and try again.",
          fieldErrors: { sku: "Enter a SKU." },
          values: INITIAL_VARIANT_FORM_STATE.values,
        }}
      />,
    );

    expect(screen.getByLabelText("SKU")).toHaveAttribute(
      "aria-describedby",
      "sku-help sku-error",
    );
    expect(screen.getByLabelText("SKU")).toHaveAttribute(
      "aria-invalid",
      "true",
    );
  });
});
