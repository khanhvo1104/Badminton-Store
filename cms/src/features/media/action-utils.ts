import {
  MEDIA_AUTH_DENIED_MESSAGE,
  MEDIA_GENERIC_FAILURE_MESSAGE,
} from "@/features/media/constants";
import {
  type AuthorizationSupabaseClient,
  authorizeCmsRequest,
} from "@/lib/auth/authorization";
import { createSupabaseServerClient } from "@/lib/supabase/server";

export async function requireMediaActionAuth(): Promise<
  | {
      ok: true;
      supabase: Awaited<ReturnType<typeof createSupabaseServerClient>>;
    }
  | { ok: false; denied: true }
  | { ok: false; denied: false }
> {
  try {
    const supabase = await createSupabaseServerClient({ canSetCookies: true });
    const authorization = await authorizeCmsRequest(
      supabase as unknown as AuthorizationSupabaseClient,
    );

    if (authorization.kind !== "authorized") {
      return { ok: false, denied: true };
    }

    return { ok: true, supabase };
  } catch {
    return { ok: false, denied: false };
  }
}

export function mediaDeniedMessage(denied: boolean): string {
  return denied ? MEDIA_AUTH_DENIED_MESSAGE : MEDIA_GENERIC_FAILURE_MESSAGE;
}
