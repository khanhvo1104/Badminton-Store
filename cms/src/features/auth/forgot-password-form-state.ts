export type ForgotPasswordFormState = {
  errorMessage: string | null;
  acknowledgement: string | null;
};

export const INITIAL_FORGOT_PASSWORD_FORM_STATE: ForgotPasswordFormState = {
  errorMessage: null,
  acknowledgement: null,
};
