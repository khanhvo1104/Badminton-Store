import { render, screen } from "@testing-library/react";
import { describe, expect, it, vi } from "vitest";

import { InventoryAdjustmentForm } from "@/features/inventory/components/inventory-adjustment-form";
import { INITIAL_INVENTORY_FORM_STATE } from "@/features/inventory/adjustment-form-state";

vi.mock("@/features/inventory/actions/adjust-inventory", () => ({
  adjustInventory: vi.fn(),
}));

vi.mock("react", async () => {
  const actual = await vi.importActual<typeof import("react")>("react");
  return {
    ...actual,
    useActionState: (
      _action: unknown,
      initialState: typeof INITIAL_INVENTORY_FORM_STATE,
    ) => [initialState, vi.fn()],
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

describe("InventoryAdjustmentForm", () => {
  it("renders fail-closed operations and reason without reserved editing", () => {
    render(
      <InventoryAdjustmentForm
        variantId={VARIANT_ID}
        initialAllowBackorder={false}
        initialState={INITIAL_INVENTORY_FORM_STATE}
      />,
    );

    expect(screen.getByLabelText("Operation")).toBeTruthy();
    expect(screen.getByLabelText("Reason")).toBeTruthy();
    expect(screen.getByLabelText("Quantity")).toBeTruthy();
    expect(screen.queryByLabelText(/reserved/i)).toBeNull();
    expect(
      screen.getByRole("button", { name: "Save adjustment" }),
    ).toBeTruthy();
  });

  it("shows sanitized field errors", () => {
    render(
      <InventoryAdjustmentForm
        variantId={VARIANT_ID}
        initialAllowBackorder={false}
        initialState={{
          status: "error",
          message: "Check the highlighted fields.",
          fieldErrors: { quantity: "Enter a whole number using digits only." },
          values: INITIAL_INVENTORY_FORM_STATE.values,
        }}
      />,
    );

    expect(
      screen.getByText("Enter a whole number using digits only."),
    ).toBeTruthy();
    expect(screen.queryByText(/sql|jwt|permission denied/i)).toBeNull();
  });
});
