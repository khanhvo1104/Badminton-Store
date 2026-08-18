import { EMPTY_PRODUCT_FORM_VALUES } from "@/features/products/product-form-state";
import {
  PRODUCT_GENERIC_FAILURE_MESSAGE,
  PRODUCT_MUTATION_AUTH_DENIED_MESSAGE,
} from "@/features/products/constants";
import type {
  ProductFormState,
  ProductFormValues,
} from "@/features/products/types";
import {
  type AuthorizationSupabaseClient,
  authorizeCmsRequest,
} from "@/lib/auth/authorization";
import { createSupabaseServerClient } from "@/lib/supabase/server";

export async function requireProductActionAuth(): Promise<
  | {
      ok: true;
      supabase: Awaited<ReturnType<typeof createSupabaseServerClient>>;
    }
  | { ok: false; state: ProductFormState }
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
        message: PRODUCT_GENERIC_FAILURE_MESSAGE,
        fieldErrors: {},
        values: EMPTY_PRODUCT_FORM_VALUES,
      },
    };
  }
}

export function denialState(values?: ProductFormValues): ProductFormState {
  return {
    status: "error",
    message: PRODUCT_MUTATION_AUTH_DENIED_MESSAGE,
    fieldErrors: {},
    values: values ?? EMPTY_PRODUCT_FORM_VALUES,
  };
}

export function errorState(
  values: ProductFormValues,
  message: string,
  fieldErrors: ProductFormState["fieldErrors"] = {},
): ProductFormState {
  return {
    status: "error",
    message,
    fieldErrors,
    values,
  };
}

export function successState(
  values: ProductFormValues,
  message: string,
): ProductFormState {
  return {
    status: "success",
    message,
    fieldErrors: {},
    values,
  };
}
