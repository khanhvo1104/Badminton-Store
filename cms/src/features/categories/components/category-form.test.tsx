import { render, screen } from "@testing-library/react";
import { describe, expect, it, vi } from "vitest";

import { CategoryForm } from "@/features/categories/components/category-form";
import { INITIAL_CATEGORY_FORM_STATE } from "@/features/categories/category-form-state";

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

vi.mock("@/features/categories/actions/create-category", () => ({
  createCategory: vi.fn(),
}));

vi.mock("@/features/categories/actions/update-category", () => ({
  updateCategory: vi.fn(),
}));

describe("CategoryForm", () => {
  it("exposes accessible labels and help text for create", () => {
    render(
      <CategoryForm
        mode="create"
        initialState={INITIAL_CATEGORY_FORM_STATE}
        parentOptions={[
          {
            id: "11111111-1111-4111-8111-111111111111",
            parentId: null,
            name: "Parent",
            isActive: true,
          },
        ]}
      />,
    );

    expect(screen.getByLabelText("Name")).toBeTruthy();
    expect(screen.getByLabelText("Slug")).toBeTruthy();
    expect(screen.getByLabelText("Description")).toBeTruthy();
    expect(screen.getByLabelText("Parent category")).toBeTruthy();
    expect(screen.getByLabelText("Sort order")).toBeTruthy();
    expect(
      screen.getByLabelText(/Active and visible to public catalog readers/i),
    ).toBeTruthy();
    expect(screen.getByLabelText("Category image")).toBeTruthy();
    expect(
      screen.getByRole("button", { name: "Create category" }),
    ).toBeTruthy();
  });
});
