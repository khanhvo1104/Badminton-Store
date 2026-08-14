"use server";

import { redirect } from "next/navigation";

import type { UpdatePasswordFormState } from "@/features/auth/update-password-form-state";
import {
  getLoginRedirectPath,
  isVerifiedRecoverySession,
  LOGIN_STATUS_PASSWORD_UPDATED,
  LOGIN_STATUS_RECOVERY_FAILED,
  PASSWORD_UPDATE_FAILED_MESSAGE,
  validateNewPassword,
} from "@/lib/auth/password-recovery";
import { createSupabaseServerClient } from "@/lib/supabase/server";

export async function updatePassword(
  _previousState: UpdatePasswordFormState,
  formData: FormData,
): Promise<UpdatePasswordFormState> {
  const password = readFormValue(formData, "password");
  const confirmation = readFormValue(formData, "confirmPassword");
  const validationMessage = validateNewPassword(password, confirmation);

  if (validationMessage) {
    return {
      errorMessage: validationMessage,
    };
  }

  const supabase = await createSupabaseServerClient({ canSetCookies: true });
  const { data, error: claimsError } = await supabase.auth.getClaims();

  if (claimsError || !isVerifiedRecoverySession(data?.claims)) {
    redirect(getLoginRedirectPath(LOGIN_STATUS_RECOVERY_FAILED));
  }

  const { error } = await supabase.auth.updateUser({ password });

  if (error) {
    return {
      errorMessage: PASSWORD_UPDATE_FAILED_MESSAGE,
    };
  }

  try {
    const { error: signOutError } = await supabase.auth.signOut();

    if (signOutError) {
      return {
        errorMessage: PASSWORD_UPDATE_FAILED_MESSAGE,
      };
    }
  } catch {
    return {
      errorMessage: PASSWORD_UPDATE_FAILED_MESSAGE,
    };
  }

  redirect(getLoginRedirectPath(LOGIN_STATUS_PASSWORD_UPDATED));
}

function readFormValue(formData: FormData, key: string) {
  const value = formData.get(key);
  return typeof value === "string" ? value : "";
}
