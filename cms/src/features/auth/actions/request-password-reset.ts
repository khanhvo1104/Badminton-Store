"use server";

import type { ForgotPasswordFormState } from "@/features/auth/forgot-password-form-state";
import {
  EMAIL_VALIDATION_MESSAGE,
  getPasswordRecoveryRedirectTo,
  isSyntacticallyValidEmail,
  PASSWORD_RECOVERY_ACKNOWLEDGEMENT,
} from "@/lib/auth/password-recovery";
import { getCmsSiteUrl } from "@/lib/env/cms-site-url";
import { createSupabaseServerClient } from "@/lib/supabase/server";

export async function requestPasswordReset(
  _previousState: ForgotPasswordFormState,
  formData: FormData,
): Promise<ForgotPasswordFormState> {
  const email = readTrimmedFormValue(formData, "email");

  if (!isSyntacticallyValidEmail(email)) {
    return {
      errorMessage: EMAIL_VALIDATION_MESSAGE,
      acknowledgement: null,
    };
  }

  const redirectTo = getPasswordRecoveryRedirectTo(getCmsSiteUrl());
  const supabase = await createSupabaseServerClient({ canSetCookies: true });

  try {
    await supabase.auth.resetPasswordForEmail(email, { redirectTo });
  } catch {
    return {
      errorMessage: null,
      acknowledgement: PASSWORD_RECOVERY_ACKNOWLEDGEMENT,
    };
  }

  return {
    errorMessage: null,
    acknowledgement: PASSWORD_RECOVERY_ACKNOWLEDGEMENT,
  };
}

function readTrimmedFormValue(formData: FormData, key: string) {
  const value = formData.get(key);
  return typeof value === "string" ? value.trim() : "";
}
