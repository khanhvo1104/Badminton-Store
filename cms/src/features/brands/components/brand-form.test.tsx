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

    expect(screen.getByLabelText("Name")).toHaveAttribute(
      "aria-describedby",
      "name-help",
    );
    expect(screen.getByLabelText("Name")).not.toHaveAttribute("aria-invalid");
    expect(document.getElementById("name-help")).toHaveTextContent(
      "Required. Up to 120 characters.",
    );
    expect(
      screen.getByRole("button", { name: "Create brand" }).closest("form"),
    ).not.toHaveAttribute("enctype");
  });

  it("associates help and error IDs and marks invalid controls", () => {
    render(
      <BrandForm
        mode="create"
        initialState={{
          status: "error",
          message: "Fix the highlighted fields and try again.",
          fieldErrors: {
            name: "Enter a brand name.",
            websiteUrl:
              "Enter an absolute HTTPS website URL, or leave the field empty.",
            sortOrder: "Sort order must be a whole number.",
            logo: "Upload a JPEG, PNG, WebP, or SVG logo up to 2 MiB.",
          },
          values: INITIAL_BRAND_FORM_STATE.values,
        }}
      />,
    );

    const name = screen.getByLabelText("Name");
    expect(name).toHaveAttribute("aria-invalid", "true");
    expect(name).toHaveAttribute("aria-describedby", "name-help name-error");
    expect(document.getElementById("name-error")).toHaveTextContent(
      "Enter a brand name.",
    );

    const website = screen.getByLabelText("Website URL");
    expect(website).toHaveAttribute("aria-invalid", "true");
    expect(website).toHaveAttribute(
      "aria-describedby",
      "website_url-help website_url-error",
    );

    const sortOrder = screen.getByLabelText("Sort order");
    expect(sortOrder).toHaveAttribute("aria-invalid", "true");
    expect(sortOrder).toHaveAttribute(
      "aria-describedby",
      "sort_order-help sort_order-error",
    );

    const logo = screen.getByLabelText("Brand logo");
    expect(logo).toHaveAttribute("aria-invalid", "true");
    expect(logo).toHaveAttribute("aria-describedby", "logo-help logo-error");
    expect(document.getElementById("logo-error")).toHaveTextContent(
      "Upload a JPEG, PNG, WebP, or SVG logo up to 2 MiB.",
    );

    const slug = screen.getByLabelText("Slug");
    expect(slug).not.toHaveAttribute("aria-invalid");
    expect(slug).toHaveAttribute("aria-describedby", "slug-help");

    const description = screen.getByLabelText("Description");
    expect(description).not.toHaveAttribute("aria-invalid");
    expect(description).toHaveAttribute("aria-describedby", "description-help");
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
