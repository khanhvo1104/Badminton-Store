import { EMPTY_CATEGORY_FORM_VALUES } from "@/features/categories/category-form-state";
import {
  CATEGORY_AUTH_DENIED_MESSAGE,
  CATEGORY_GENERIC_FAILURE_MESSAGE,
} from "@/features/categories/constants";
import type {
  CategoryFormState,
  CategoryFormValues,
} from "@/features/categories/types";
import {
  type AuthorizationSupabaseClient,
  authorizeCmsRequest,
} from "@/lib/auth/authorization";
import { createSupabaseServerClient } from "@/lib/supabase/server";

export async function requireCategoryActionAuth(): Promise<
  | {
      ok: true;
      supabase: Awaited<ReturnType<typeof createSupabaseServerClient>>;
    }
  | { ok: false; state: CategoryFormState }
> {
  try {
    const supabase = await createSupabaseServerClient({ canSetCookies: true });
    const authorization = await authorizeCmsRequest(
      supabase as unknown as AuthorizationSupabaseClient,
    );

    if (authorization.kind !== "authorized") {
      return { ok: false, state: denialState() };
    }

    return { ok: true, supabase };
  } catch {
    return {
      ok: false,
      state: {
        status: "error",
        message: CATEGORY_GENERIC_FAILURE_MESSAGE,
        fieldErrors: {},
        values: EMPTY_CATEGORY_FORM_VALUES,
      },
    };
  }
}

export function denialState(values?: CategoryFormValues): CategoryFormState {
  return {
    status: "error",
    message: CATEGORY_AUTH_DENIED_MESSAGE,
    fieldErrors: {},
    values: values ?? EMPTY_CATEGORY_FORM_VALUES,
  };
}

export function errorState(
  values: CategoryFormValues,
  message: string,
  fieldErrors: CategoryFormState["fieldErrors"] = {},
): CategoryFormState {
  return {
    status: "error",
    message,
    fieldErrors,
    values,
  };
}

export function successState(
  values: CategoryFormValues,
  message: string,
): CategoryFormState {
  return {
    status: "success",
    message,
    fieldErrors: {},
    values,
  };
}

export function readConfirmation(formData: FormData, key: string): boolean {
  const value = formData.get(key);
  if (typeof value !== "string") {
    return false;
  }
  const normalized = value.trim().toLowerCase();
  return (
    normalized === "on" ||
    normalized === "true" ||
    normalized === "1" ||
    normalized === "yes" ||
    normalized === "confirm"
  );
}
