import type { StaffMutationFormState } from "@/features/staff/types";

export const INITIAL_STAFF_MUTATION_STATE: StaffMutationFormState = {
  status: "idle",
  message: "",
  fieldErrors: {},
  values: { confirmed: false },
};

export const INITIAL_STAFF_INVITE_STATE = {
  status: "idle" as const,
  message: "",
  fieldErrors: {},
  values: {
    email: "",
    fullName: "",
    role: "staff" as const,
    confirmed: false,
  },
};
