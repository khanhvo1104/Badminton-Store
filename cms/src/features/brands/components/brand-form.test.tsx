import { render, screen } from "@testing-library/react";
import { describe, expect, it, vi } from "vitest";

import { BrandForm } from "@/features/brands/components/brand-form";
import { INITIAL_BRAND_FORM_STATE } from "@/features/brands/brand-form-state";

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

vi.mock("@/features/brands/actions/create-brand", () => ({
  createBrand: vi.fn(),
}));

vi.mock("@/features/brands/actions/update-brand", () => ({
  updateBrand: vi.fn(),
}));

describe("BrandForm", () => {
  it("exposes accessible labels and help text for create", () => {
    render(<BrandForm mode="create" initialState={INITIAL_BRAND_FORM_STATE} />);

    expect(screen.getByLabelText("Name")).toBeTruthy();
    expect(screen.getByLabelText("Slug")).toBeTruthy();
    expect(screen.getByLabelText("Description")).toBeTruthy();
    expect(screen.getByLabelText("Website URL")).toBeTruthy();
    expect(screen.getByLabelText("Country of origin")).toBeTruthy();
    expect(screen.getByLabelText("Sort order")).toBeTruthy();
    expect(
      screen.getByLabelText(/Active and visible to public catalog readers/i),
    ).toBeTruthy();
    expect(screen.getByLabelText("Brand logo")).toBeTruthy();
    expect(screen.getByRole("button", { name: "Create brand" })).toBeTruthy();
  });

  it("renders an existing SVG logo through an img, never inline", () => {
    const { container } = render(
      <BrandForm
        mode="edit"
        brandId="20000000-0000-4000-8000-000000000001"
        initialState={{
          ...INITIAL_BRAND_FORM_STATE,
          values: {
            ...INITIAL_BRAND_FORM_STATE.values,
            name: "Yonex",
            slug: "yonex",
          },
        }}
        currentLogoUrl="https://example.supabase.co/storage/v1/object/public/brand-assets/20000000-0000-4000-8000-000000000001/logo.svg"
      />,
    );

    const image = screen.getByAltText("Current brand logo");
    expect(image.tagName).toBe("IMG");
    expect(image).toHaveAttribute(
      "src",
      expect.stringContaining("brand-assets/"),
    );
    expect(container.querySelector("svg")).toBeNull();
  });
});
