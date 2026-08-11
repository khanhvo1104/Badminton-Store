"use server";

import { redirect } from "next/navigation";

import type { LoginFormState } from "@/features/auth/login-form-state";
import {
  AUTH_FAILURE_MESSAGE,
  CMS_DASHBOARD_PATH,
} from "@/lib/auth/authorization";
import { createSupabaseServerClient } from "@/lib/supabase/server";

export async function login(
  _previousState: LoginFormState,
  formData: FormData,
): Promise<LoginFormState> {
  const email = readTrimmedFormValue(formData, "email");
  const password = readTrimmedFormValue(formData, "password");

  if (!email || !password) {
    return {
      errorMessage: AUTH_FAILURE_MESSAGE,
    };
  }

  const supabase = await createSupabaseServerClient({ canSetCookies: true });
  const { error } = await supabase.auth.signInWithPassword({
    email,
    password,
  });

  if (error) {
    return {
      errorMessage: AUTH_FAILURE_MESSAGE,
    };
  }

  redirect(CMS_DASHBOARD_PATH);
}

function readTrimmedFormValue(formData: FormData, key: string) {
  const value = formData.get(key);
  return typeof value === "string" ? value.trim() : "";
}
