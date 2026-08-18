import type {
  InventoryFormState,
  InventoryFormValues,
} from "@/features/inventory/types";

export const EMPTY_INVENTORY_FORM_VALUES: InventoryFormValues = {
  operation: "add_stock",
  quantity: "",
  allowBackorder: "false",
  reason: "",
  note: "",
};

export const INITIAL_INVENTORY_FORM_STATE: InventoryFormState = {
  status: "idle",
  message: null,
  fieldErrors: {},
  values: EMPTY_INVENTORY_FORM_VALUES,
};

export function inventoryFormStateFromValues(
  values: InventoryFormValues,
): InventoryFormState {
  return {
    status: "idle",
    message: null,
    fieldErrors: {},
    values,
  };
}
