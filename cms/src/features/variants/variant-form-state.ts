import type {
  VariantFormState,
  VariantFormValues,
} from "@/features/variants/types";

export const EMPTY_VARIANT_FORM_VALUES: VariantFormValues = {
  sku: "",
  name: "",
  colorName: "",
  colorHex: "",
  racketWeightClass: "",
  gripSize: "",
  shoeSize: "",
  clothingSize: "",
  unit: "item",
  price: "",
  compareAtPrice: "",
  costPrice: "",
  barcode: "",
  barcodeClear: false,
  attributes: "",
  isDefault: "false",
  isActive: "true",
  sortOrder: "0",
};

export const INITIAL_VARIANT_FORM_STATE: VariantFormState = {
  status: "idle",
  message: null,
  fieldErrors: {},
  values: EMPTY_VARIANT_FORM_VALUES,
};

export function variantFormStateFromValues(
  values: VariantFormValues,
): VariantFormState {
  return {
    status: "idle",
    message: null,
    fieldErrors: {},
    values,
  };
}
