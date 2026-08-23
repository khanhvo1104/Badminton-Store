import "@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "@supabase/supabase-js";
import { withSupabase } from "@supabase/server";

import { finalizeFailureMessage, finalizeInvitedStaff } from "./invite-flow.ts";
import {
  AUTH_DENIED_MESSAGE,
  buildInviteRedirectTo,
  INVALID_REQUEST_MESSAGE,
  mapInviteError,
  mapInviteStatus,
  parseInviteBody,
  readSubject,
  type InviteBodyInput,
} from "./invite-helpers.ts";

export default {
  fetch: withSupabase({ auth: "user" }, async (req, ctx) => {
    if (req.method !== "POST") {
      return json({ error: INVALID_REQUEST_MESSAGE }, 405);
    }

    const actorId = readSubject(ctx.userClaims);
    if (!actorId) {
      return json({ error: AUTH_DENIED_MESSAGE }, 403);
    }

    const authorizationHeader = req.headers.get("Authorization");
    if (!authorizationHeader) {
      return json({ error: AUTH_DENIED_MESSAGE }, 403);
    }

    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const supabaseAnonKey =
      Deno.env.get("SUPABASE_ANON_KEY") ??
      Deno.env.get("SUPABASE_PUBLISHABLE_KEY");
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    const cmsSiteUrl = Deno.env.get("CMS_SITE_URL");

    if (!supabaseUrl || !supabaseAnonKey || !serviceRoleKey || !cmsSiteUrl) {
      return json({ error: finalizeFailureMessage({ ok: false, compensated: false }) }, 500);
    }

    const userClient = createClient(supabaseUrl, supabaseAnonKey, {
      auth: { persistSession: false, autoRefreshToken: false },
      global: { headers: { Authorization: authorizationHeader } },
    });

    const { data: profile, error: profileError } = await userClient
      .from("profiles")
      .select("role, is_active")
      .eq("id", actorId)
      .maybeSingle();

    if (
      profileError ||
      !profile ||
      profile.role !== "admin" ||
      profile.is_active !== true
    ) {
      return json({ error: AUTH_DENIED_MESSAGE }, 403);
    }

    let body: InviteBodyInput;
    try {
      body = (await req.json()) as InviteBodyInput;
    } catch {
      return json({ error: INVALID_REQUEST_MESSAGE }, 400);
    }

    const parsed = parseInviteBody(body);
    if (!parsed.ok) {
      return json({ error: INVALID_REQUEST_MESSAGE }, 400);
    }

    const { email, role, fullName } = parsed;

    const redirectTo = buildInviteRedirectTo(cmsSiteUrl);
    if (!redirectTo) {
      return json({ error: finalizeFailureMessage({ ok: false, compensated: false }) }, 500);
    }

    const adminClient = createClient(supabaseUrl, serviceRoleKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    });

    const { data: inviteData, error: inviteError } =
      await adminClient.auth.admin.inviteUserByEmail(email, {
        redirectTo,
        data: fullName ? { full_name: fullName } : undefined,
      });

    if (inviteError) {
      return json(
        { error: mapInviteError(inviteError as { message?: string; status?: number }) },
        mapInviteStatus(inviteError as { message?: string; status?: number }),
      );
    }

    const invitedUserId = inviteData.user?.id;
    if (!invitedUserId) {
      return json({ error: finalizeFailureMessage({ ok: false, compensated: false }) }, 500);
    }

    const finalized = await finalizeInvitedStaff({
      adminClient,
      actorId,
      invitedUserId,
      email,
      role,
      fullName,
    });

    if (!finalized.ok) {
      return json({ error: finalizeFailureMessage(finalized) }, 500);
    }

    return json({ ok: true, profileId: finalized.profileId }, 200);
  }),
};

function json(body: Record<string, unknown>, status: number): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}
