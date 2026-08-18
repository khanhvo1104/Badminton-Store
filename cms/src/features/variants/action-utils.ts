import { EMPTY_VARIANT_FORM_VALUES } from "@/features/variants/variant-form-state";
import {
  VARIANT_AUTH_DENIED_MESSAGE,
  VARIANT_GENERIC_FAILURE_MESSAGE,
} from "@/features/variants/constants";
import type {
  VariantFormState,
  VariantFormValues,
} from "@/features/variants/types";
import {
  type AuthorizationSupabaseClient,
  authorizeCmsRequest,
} from "@/lib/auth/authorization";
import { createSupabaseServerClient } from "@/lib/supabase/server";

export async function requireVariantActionAuth(): Promise<
  | {
      ok: true;
      supabase: Awaited<ReturnType<typeof createSupabaseServerClient>>;
    }
  | { ok: false; state: VariantFormState }
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
        message: VARIANT_GENERIC_FAILURE_MESSAGE,
        fieldErrors: {},
        values: EMPTY_VARIANT_FORM_VALUES,
      },
    };
  }
}

export function denialState(values?: VariantFormValues): VariantFormState {
  return {
    status: "error",
    message: VARIANT_AUTH_DENIED_MESSAGE,
    fieldErrors: {},
    values: values ?? EMPTY_VARIANT_FORM_VALUES,
  };
}

export function errorState(
  values: VariantFormValues,
  message: string,
  fieldErrors: VariantFormState["fieldErrors"] = {},
): VariantFormState {
  return {
    status: "error",
    message,
    fieldErrors,
    values,
  };
}
