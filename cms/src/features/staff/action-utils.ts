import {
  STAFF_GENERIC_FAILURE_MESSAGE,
  STAFF_MUTATION_AUTH_DENIED_MESSAGE,
} from "@/features/staff/constants";
import type {
  StaffInviteFormState,
  StaffMutationFormState,
} from "@/features/staff/types";
import {
  type AuthorizationSupabaseClient,
  authorizeCmsAdminRequest,
} from "@/lib/auth/authorization";
import { createSupabaseServerClient } from "@/lib/supabase/server";

export async function requireStaffAdminActionAuth(): Promise<
  | {
      ok: true;
      supabase: Awaited<ReturnType<typeof createSupabaseServerClient>>;
      actorId: string;
    }
  | { ok: false; state: StaffMutationFormState | StaffInviteFormState }
> {
  try {
    const supabase = await createSupabaseServerClient({ canSetCookies: true });
    const authorization = await authorizeCmsAdminRequest(
      supabase as unknown as AuthorizationSupabaseClient,
    );

    if (authorization.kind !== "authorized") {
      return { ok: false, state: denialState() };
    }

    return {
      ok: true,
      supabase,
      actorId: authorization.profile.id,
    };
  } catch {
    return {
      ok: false,
      state: {
        status: "error",
        message: STAFF_GENERIC_FAILURE_MESSAGE,
        fieldErrors: {},
        values: { confirmed: false },
      },
    };
  }
}

export async function getStaffActionAccessToken(
  supabase: Awaited<ReturnType<typeof createSupabaseServerClient>>,
): Promise<string | null> {
  try {
    const { data, error } = await supabase.auth.getSession();
    if (error || !data.session?.access_token) {
      return null;
    }
    return data.session.access_token;
  } catch {
    return null;
  }
}

export function denialState(): StaffMutationFormState {
  return {
    status: "error",
    message: STAFF_MUTATION_AUTH_DENIED_MESSAGE,
    fieldErrors: {},
    values: { confirmed: false },
  };
}

export function readConfirmation(formData: FormData, key: string): boolean {
  const value = formData.get(key);
  if (typeof value !== "string") {
    return false;
  }
  return ["on", "true", "1", "yes"].includes(value.trim().toLowerCase());
}
