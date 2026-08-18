import type { ProductFormState, ProductFormValues } from "@/features/products/types";

export const EMPTY_PRODUCT_FORM_VALUES: ProductFormValues = {
  categoryId: "",
  brandId: "",
  name: "",
  slug: "",
  slugManual: false,
  shortDescription: "",
  description: "",
  specifications: "",
  searchKeywords: "",
  status: "draft",
  isFeatured: false,
  publishedAt: "",
};

export const INITIAL_PRODUCT_FORM_STATE: ProductFormState = {
  status: "idle",
  message: null,
  fieldErrors: {},
  values: EMPTY_PRODUCT_FORM_VALUES,
};

export function productFormStateFromValues(
  values: ProductFormValues,
): ProductFormState {
  return {
    status: "idle",
    message: null,
    fieldErrors: {},
    values,
  };
}
