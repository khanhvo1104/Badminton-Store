import "@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2";
import { withSupabase } from "@supabase/server";

const AUTH_DENIED_MESSAGE =
  "You don't have permission to invite staff members.";
const GENERIC_FAILURE_MESSAGE =
  "We couldn't send that invitation. Try again later.";
const INVALID_REQUEST_MESSAGE =
  "Check the email address and role, then try again.";
const RATE_LIMIT_MESSAGE =
  "Email sending is temporarily limited. Wait a few minutes and try again, or ask your operator to review SMTP rate limits.";
const DUPLICATE_MESSAGE =
  "That email already belongs to an account. Update the existing staff member instead of sending a new invitation.";

const EMAIL_PATTERN = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

type InviteBody = {
  email?: unknown;
  role?: unknown;
  fullName?: unknown;
};

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
      return json({ error: GENERIC_FAILURE_MESSAGE }, 500);
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

    let body: InviteBody;
    try {
      body = (await req.json()) as InviteBody;
    } catch {
      return json({ error: INVALID_REQUEST_MESSAGE }, 400);
    }

    const email = readEmail(body.email);
    const role = readRole(body.role);
    const fullName = readFullName(body.fullName);

    if (!email || !role) {
      return json({ error: INVALID_REQUEST_MESSAGE }, 400);
    }

    const redirectTo = buildInviteRedirectTo(cmsSiteUrl);
    if (!redirectTo) {
      return json({ error: GENERIC_FAILURE_MESSAGE }, 500);
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
        { error: mapInviteError(inviteError) },
        mapInviteStatus(inviteError),
      );
    }

    const invitedUserId = inviteData.user?.id;
    if (!invitedUserId) {
      return json({ error: GENERIC_FAILURE_MESSAGE }, 500);
    }

    const profilePatch: Record<string, string | boolean> = {
      role,
      is_active: true,
    };
    if (fullName) {
      profilePatch.full_name = fullName;
    }

    const { error: profileUpdateError } = await adminClient
      .from("profiles")
      .update(profilePatch)
      .eq("id", invitedUserId);

    if (profileUpdateError) {
      return json({ error: GENERIC_FAILURE_MESSAGE }, 500);
    }

    const { error: auditError } = await adminClient
      .from("staff_management_events")
      .insert({
        actor_id: actorId,
        target_id: invitedUserId,
        action: "invite",
        new_role: role,
        new_is_active: true,
        target_email: email,
      });

    if (auditError) {
      return json({ error: GENERIC_FAILURE_MESSAGE }, 500);
    }

    return json({ ok: true, profileId: invitedUserId }, 200);
  }),
};

function json(body: Record<string, unknown>, status: number): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

function readSubject(claims: unknown): string | null {
  if (!isRecord(claims)) {
    return null;
  }
  const subject = claims.sub;
  return typeof subject === "string" && subject.trim() ? subject : null;
}

function readEmail(value: unknown): string | null {
  if (typeof value !== "string") {
    return null;
  }
  const normalized = value.trim().toLowerCase();
  if (!normalized || normalized.length > 254 || !EMAIL_PATTERN.test(normalized)) {
    return null;
  }
  return normalized;
}

function readRole(value: unknown): "staff" | "admin" | null {
  if (value !== "staff" && value !== "admin") {
    return null;
  }
  return value;
}

function readFullName(value: unknown): string | null {
  if (value === null || value === undefined || value === "") {
    return null;
  }
  if (typeof value !== "string") {
    return null;
  }
  const trimmed = value.trim().replace(/\s+/g, " ");
  if (!trimmed || trimmed.length > 120) {
    return null;
  }
  return trimmed;
}

function buildInviteRedirectTo(rawSiteUrl: string): string | null {
  try {
    const site = new URL(rawSiteUrl);
    if (!["http:", "https:"].includes(site.protocol)) {
      return null;
    }
    const callback = new URL("/auth/callback", site);
    callback.searchParams.set("next", "/update-password");
    return callback.toString();
  } catch {
    return null;
  }
}

function mapInviteError(error: { message?: string; status?: number }): string {
  const message = typeof error.message === "string" ? error.message.toLowerCase() : "";
  const status = typeof error.status === "number" ? error.status : 0;

  if (
    status === 429 ||
    message.includes("rate limit") ||
    message.includes("too many requests") ||
    message.includes("email rate limit")
  ) {
    return RATE_LIMIT_MESSAGE;
  }

  if (
    message.includes("already been registered") ||
    message.includes("already exists") ||
    message.includes("user already registered")
  ) {
    return DUPLICATE_MESSAGE;
  }

  return GENERIC_FAILURE_MESSAGE;
}

function mapInviteStatus(error: { message?: string; status?: number }): number {
  const message = typeof error.message === "string" ? error.message.toLowerCase() : "";
  const status = typeof error.status === "number" ? error.status : 0;

  if (
    status === 429 ||
    message.includes("rate limit") ||
    message.includes("too many requests")
  ) {
    return 429;
  }

  if (
    message.includes("already been registered") ||
    message.includes("already exists") ||
    message.includes("user already registered")
  ) {
    return 409;
  }

  return 400;
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null;
}
