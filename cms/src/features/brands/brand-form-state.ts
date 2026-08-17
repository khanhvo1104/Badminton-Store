import type {
  BrandActivationState,
  BrandFormState,
  BrandFormValues,
} from "@/features/brands/types";

export const EMPTY_BRAND_FORM_VALUES: BrandFormValues = {
  name: "",
  slug: "",
  description: "",
  websiteUrl: "",
  countryOfOrigin: "",
  sortOrder: "0",
  isActive: true,
};

export const INITIAL_BRAND_FORM_STATE: BrandFormState = {
  status: "idle",
  message: null,
  fieldErrors: {},
  values: EMPTY_BRAND_FORM_VALUES,
};

export const INITIAL_BRAND_ACTIVATION_STATE: BrandActivationState = {
  status: "idle",
  message: null,
  fieldErrors: {},
  isActive: true,
};

export function brandFormStateFromValues(
  values: BrandFormValues,
): BrandFormState {
  return {
    status: "idle",
    message: null,
    fieldErrors: {},
    values,
  };
}

export function createBrandFormState(
  values: BrandFormValues,
  overrides: Partial<Omit<BrandFormState, "values">> = {},
): BrandFormState {
  return {
    status: "idle",
    message: null,
    fieldErrors: {},
    ...overrides,
    values,
  };
}
