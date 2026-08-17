import { EMPTY_BRAND_FORM_VALUES } from "@/features/brands/brand-form-state";
import {
  BRAND_AUTH_DENIED_MESSAGE,
  BRAND_GENERIC_FAILURE_MESSAGE,
} from "@/features/brands/constants";
import type { BrandFormState, BrandFormValues } from "@/features/brands/types";
import {
  type AuthorizationSupabaseClient,
  authorizeCmsRequest,
} from "@/lib/auth/authorization";
import { createSupabaseServerClient } from "@/lib/supabase/server";

export async function requireBrandActionAuth(): Promise<
  | {
      ok: true;
      supabase: Awaited<ReturnType<typeof createSupabaseServerClient>>;
    }
  | { ok: false; state: BrandFormState }
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
        message: BRAND_GENERIC_FAILURE_MESSAGE,
        fieldErrors: {},
        values: EMPTY_BRAND_FORM_VALUES,
      },
    };
  }
}

export function denialState(values?: BrandFormValues): BrandFormState {
  return {
    status: "error",
    message: BRAND_AUTH_DENIED_MESSAGE,
    fieldErrors: {},
    values: values ?? EMPTY_BRAND_FORM_VALUES,
  };
}

export function errorState(
  values: BrandFormValues,
  message: string,
  fieldErrors: BrandFormState["fieldErrors"] = {},
): BrandFormState {
  return {
    status: "error",
    message,
    fieldErrors,
    values,
  };
}

export function successState(
  values: BrandFormValues,
  message: string,
): BrandFormState {
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
