import type {
  CategoryActivationState,
  CategoryFormState,
  CategoryFormValues,
} from "@/features/categories/types";

export const EMPTY_CATEGORY_FORM_VALUES: CategoryFormValues = {
  name: "",
  slug: "",
  description: "",
  parentId: "",
  sortOrder: "0",
  isActive: true,
};

export const INITIAL_CATEGORY_FORM_STATE: CategoryFormState = {
  status: "idle",
  message: null,
  fieldErrors: {},
  values: EMPTY_CATEGORY_FORM_VALUES,
};

export const INITIAL_CATEGORY_ACTIVATION_STATE: CategoryActivationState = {
  status: "idle",
  message: null,
  fieldErrors: {},
  isActive: true,
};

export function categoryFormStateFromValues(
  values: CategoryFormValues,
): CategoryFormState {
  return {
    status: "idle",
    message: null,
    fieldErrors: {},
    values,
  };
}

export function createCategoryFormState(
  values: CategoryFormValues,
  overrides: Partial<Omit<CategoryFormState, "values">> = {},
): CategoryFormState {
  return {
    status: "idle",
    message: null,
    fieldErrors: {},
    ...overrides,
    values,
  };
}
