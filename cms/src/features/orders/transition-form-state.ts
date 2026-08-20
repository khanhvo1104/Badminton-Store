import type {
  OrderTransitionFormState,
  OrderTransitionFormValues,
} from "@/features/orders/types";

export const EMPTY_ORDER_TRANSITION_VALUES: OrderTransitionFormValues = {
  toStatus: "",
  note: "",
  confirmed: "",
};

export const INITIAL_ORDER_TRANSITION_FORM_STATE: OrderTransitionFormState = {
  status: "idle",
  message: null,
  fieldErrors: {},
  values: EMPTY_ORDER_TRANSITION_VALUES,
};
