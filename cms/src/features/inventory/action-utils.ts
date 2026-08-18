import { EMPTY_INVENTORY_FORM_VALUES } from "@/features/inventory/adjustment-form-state";
import {
  INVENTORY_GENERIC_FAILURE_MESSAGE,
  INVENTORY_MUTATION_AUTH_DENIED_MESSAGE,
} from "@/features/inventory/constants";
import type {
  InventoryFormState,
  InventoryFormValues,
} from "@/features/inventory/types";
import {
  type AuthorizationSupabaseClient,
  authorizeCmsRequest,
} from "@/lib/auth/authorization";
import { createSupabaseServerClient } from "@/lib/supabase/server";

export async function requireInventoryActionAuth(): Promise<
  | {
      ok: true;
      supabase: Awaited<ReturnType<typeof createSupabaseServerClient>>;
    }
  | { ok: false; state: InventoryFormState }
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
        message: INVENTORY_GENERIC_FAILURE_MESSAGE,
        fieldErrors: {},
        values: EMPTY_INVENTORY_FORM_VALUES,
      },
    };
  }
}

export function denialState(values?: InventoryFormValues): InventoryFormState {
  return {
    status: "error",
    message: INVENTORY_MUTATION_AUTH_DENIED_MESSAGE,
    fieldErrors: {},
    values: values ?? EMPTY_INVENTORY_FORM_VALUES,
  };
}

export function errorState(
  values: InventoryFormValues,
  message: string,
  fieldErrors: InventoryFormState["fieldErrors"] = {},
): InventoryFormState {
  return {
    status: "error",
    message,
    fieldErrors,
    values,
  };
}
