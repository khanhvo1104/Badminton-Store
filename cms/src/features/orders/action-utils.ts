import { EMPTY_ORDER_TRANSITION_VALUES } from "@/features/orders/transition-form-state";
import {
  ORDERS_GENERIC_FAILURE_MESSAGE,
  ORDERS_MUTATION_AUTH_DENIED_MESSAGE,
} from "@/features/orders/constants";
import type {
  OrderTransitionFormState,
  OrderTransitionFormValues,
} from "@/features/orders/types";
import {
  type AuthorizationSupabaseClient,
  authorizeCmsRequest,
} from "@/lib/auth/authorization";
import { createSupabaseServerClient } from "@/lib/supabase/server";

export async function requireOrdersActionAuth(): Promise<
  | {
      ok: true;
      supabase: Awaited<ReturnType<typeof createSupabaseServerClient>>;
    }
  | { ok: false; state: OrderTransitionFormState }
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
        message: ORDERS_GENERIC_FAILURE_MESSAGE,
        fieldErrors: {},
        values: EMPTY_ORDER_TRANSITION_VALUES,
      },
    };
  }
}

export function denialState(
  values?: OrderTransitionFormValues,
): OrderTransitionFormState {
  return {
    status: "error",
    message: ORDERS_MUTATION_AUTH_DENIED_MESSAGE,
    fieldErrors: {},
    values: values ?? EMPTY_ORDER_TRANSITION_VALUES,
  };
}

export function errorState(
  values: OrderTransitionFormValues,
  message: string,
  fieldErrors: OrderTransitionFormState["fieldErrors"] = {},
): OrderTransitionFormState {
  return {
    status: "error",
    message,
    fieldErrors,
    values,
  };
}
