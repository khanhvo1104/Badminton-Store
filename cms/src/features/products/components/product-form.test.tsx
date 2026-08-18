import { render, screen } from "@testing-library/react";
import { describe, expect, it, vi } from "vitest";

import { ProductForm } from "@/features/products/components/product-form";
import { INITIAL_PRODUCT_FORM_STATE } from "@/features/products/product-form-state";

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

vi.mock("@/features/products/actions/create-product", () => ({
  createProduct: vi.fn(),
}));

vi.mock("@/features/products/actions/update-product", () => ({
  updateProduct: vi.fn(),
}));

const categories = [
  {
    id: "10000000-0000-4000-8000-000000000001",
    name: "Rackets",
    isActive: true,
  },
];

const brands = [
  {
    id: "20000000-0000-4000-8000-000000000001",
    name: "Yonex",
    isActive: false,
  },
];

describe("ProductForm", () => {
  it("exposes accessible labels and help text for create", () => {
    render(
      <ProductForm
        mode="create"
        initialState={INITIAL_PRODUCT_FORM_STATE}
        categories={categories}
        brands={brands}
      />,
    );

    expect(screen.getByLabelText("Category")).toBeTruthy();
    expect(screen.getByLabelText("Brand")).toBeTruthy();
    expect(screen.getByLabelText("Name")).toBeTruthy();
    expect(screen.getByLabelText("Slug")).toBeTruthy();
    expect(screen.getByLabelText("Short description")).toBeTruthy();
    expect(screen.getByLabelText("Description")).toBeTruthy();
    expect(screen.getByLabelText("Specifications")).toBeTruthy();
    expect(screen.getByLabelText("Search keywords")).toBeTruthy();
    expect(screen.getByLabelText("Status")).toBeTruthy();
    expect(screen.getByLabelText("Published at")).toBeTruthy();
    expect(screen.getByLabelText(/Featured product/i)).toBeTruthy();
    expect(screen.getByRole("button", { name: "Create product" })).toBeTruthy();
    expect(screen.getByText("Yonex (inactive)")).toBeInTheDocument();
  });

  it("associates help and error IDs and marks invalid controls", () => {
    render(
      <ProductForm
        mode="create"
        initialState={{
          status: "error",
          message: "Fix the highlighted fields and try again.",
          fieldErrors: {
            name: "Enter a product name.",
            specifications:
              "Specifications must be a JSON object with bounded keys and values.",
          },
          values: INITIAL_PRODUCT_FORM_STATE.values,
        }}
        categories={categories}
        brands={brands}
      />,
    );

    expect(screen.getByLabelText("Name")).toHaveAttribute(
      "aria-describedby",
      "name-help name-error",
    );
    expect(screen.getByLabelText("Name")).toHaveAttribute(
      "aria-invalid",
      "true",
    );
    expect(document.getElementById("specifications-error")).toHaveTextContent(
      "Specifications must be a JSON object with bounded keys and values.",
    );
  });

  it("does not submit a hidden product id in edit mode", () => {
    render(
      <ProductForm
        mode="edit"
        productId="30000000-0000-4000-8000-000000000001"
        initialState={INITIAL_PRODUCT_FORM_STATE}
        categories={categories}
        brands={brands}
      />,
    );

    expect(
      document.querySelector('input[type="hidden"][name="id"]'),
    ).toBeNull();
  });
});
