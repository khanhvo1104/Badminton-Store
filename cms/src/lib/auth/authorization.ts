export const CMS_DASHBOARD_PATH = "/dashboard";
export const CMS_LOGIN_PATH = "/login";
export const CMS_UNAUTHORIZED_PATH = "/unauthorized";
export const CMS_FORGOT_PASSWORD_PATH = "/forgot-password";
export const CMS_UPDATE_PASSWORD_PATH = "/update-password";
export const CMS_AUTH_CALLBACK_PATH = "/auth/callback";
export const CMS_PROFILE_COLUMNS = "id, full_name, role, is_active";

export const AUTH_FAILURE_MESSAGE =
  "We couldn't sign you in with those credentials.";

export type AuthorizedCmsProfile = {
  id: string;
  fullName: string | null;
  role: "staff" | "admin";
  isActive: true;
};

export type CmsAuthorizationResult =
  | { kind: "anonymous" }
  | { kind: "unauthorized" }
  | {
      kind: "authorized";
      profile: AuthorizedCmsProfile;
    };

export type CmsAdminAuthorizationResult =
  | { kind: "anonymous" }
  | { kind: "unauthorized" }
  | {
      kind: "authorized";
      profile: AuthorizedCmsProfile & { role: "admin" };
    };

type ClaimsResponse = {
  data: {
    claims?: {
      sub?: unknown;
      amr?: unknown;
    } | null;
  } | null;
  error: unknown;
};

type ProfileQueryResponse = {
  data: unknown;
  error: unknown;
};

type AuthorizedProfile = {
  id: string;
  fullName: string | null;
  role: "staff" | "admin";
  isActive: true;
};

export type AuthorizationSupabaseClient = {
  auth: {
    getClaims: () => Promise<ClaimsResponse>;
  };
  from: (table: "profiles") => {
    select: (columns: string) => {
      eq: (
        column: "id",
        value: string,
      ) => {
        maybeSingle: () =>
          | PromiseLike<ProfileQueryResponse>
          | ProfileQueryResponse;
      };
    };
  };
};

/**
 * Authentication methods GoTrue treats as recovery sessions.
 *
 * PKCE `resetPasswordForEmail` stores flow state as `models.Recovery`, whose
 * String() value is `recovery` and is copied into JWT `amr[].method`.
 * `Session.IsRecovery()` / `AuthenticationMethod.IsRecovery()` also return true
 * for `otp` and `magiclink`.
 *
 * Claim objects use `{ method, timestamp }` per Supabase jwt-fields and
 * `@supabase/auth-js` `AMREntry`. `JwtPayload.amr` also allows RFC-8176 strings.
 */
export const GOTRUE_RECOVERY_AMR_METHODS = [
  "recovery",
  "otp",
  "magiclink",
] as const;

const RECOVERY_AMR_METHOD_SET = new Set<string>(GOTRUE_RECOVERY_AMR_METHODS);

export async function getVerifiedSubject(
  supabase: Pick<AuthorizationSupabaseClient, "auth">,
): Promise<string | null> {
  try {
    const { data, error } = await supabase.auth.getClaims();

    if (error) {
      return null;
    }

    return readVerifiedSubject(data?.claims);
  } catch {
    return null;
  }
}

export function isVerifiedRecoverySession(claims: unknown): boolean {
  if (!readVerifiedSubject(claims)) {
    return false;
  }

  return isRecord(claims) && amrIncludesRecovery(claims.amr);
}

export async function authorizeCmsAdminRequest(
  supabase: AuthorizationSupabaseClient,
): Promise<CmsAdminAuthorizationResult> {
  const authorization = await authorizeCmsRequest(supabase);
  if (authorization.kind !== "authorized") {
    return authorization;
  }

  if (authorization.profile.role !== "admin") {
    return { kind: "unauthorized" };
  }

  return {
    kind: "authorized",
    profile: {
      ...authorization.profile,
      role: "admin",
    },
  };
}

export async function authorizeCmsRequest(
  supabase: AuthorizationSupabaseClient,
): Promise<CmsAuthorizationResult> {
  let claims: unknown;

  try {
    const { data, error } = await supabase.auth.getClaims();

    if (error) {
      return { kind: "anonymous" };
    }

    claims = data?.claims;
  } catch {
    return { kind: "anonymous" };
  }

  const subject = readVerifiedSubject(claims);

  if (!subject) {
    return { kind: "anonymous" };
  }

  if (isVerifiedRecoverySession(claims)) {
    return { kind: "unauthorized" };
  }

  let data: unknown;
  let error: unknown;

  try {
    ({ data, error } = await supabase
      .from("profiles")
      .select(CMS_PROFILE_COLUMNS)
      .eq("id", subject)
      .maybeSingle());
  } catch {
    return { kind: "unauthorized" };
  }

  if (error) {
    return { kind: "unauthorized" };
  }

  const profile = parseAuthorizedProfile(data, subject);
  if (!profile) {
    return { kind: "unauthorized" };
  }

  return {
    kind: "authorized",
    profile,
  };
}

function parseAuthorizedProfile(
  data: unknown,
  subject: string,
): AuthorizedProfile | null {
  if (!isRecord(data)) {
    return null;
  }

  const id = data.id;
  const fullName = data.full_name;
  const role = data.role;
  const isActive = data.is_active;

  if (typeof id !== "string" || id !== subject) {
    return null;
  }

  if (fullName !== null && typeof fullName !== "string") {
    return null;
  }

  if (isActive !== true) {
    return null;
  }

  if (role !== "staff" && role !== "admin") {
    return null;
  }

  return {
    id,
    fullName,
    role: role as "staff" | "admin",
    isActive,
  };
}

function readVerifiedSubject(claims: unknown): string | null {
  if (!isRecord(claims)) {
    return null;
  }

  const subject = claims.sub;
  return typeof subject === "string" && subject.trim() ? subject : null;
}

function amrIncludesRecovery(amr: unknown): boolean {
  if (!Array.isArray(amr)) {
    return false;
  }

  return amr.some((entry) => {
    if (typeof entry === "string") {
      return RECOVERY_AMR_METHOD_SET.has(entry);
    }

    return isRecord(entry) && isRecoveryAmrMethod(entry.method);
  });
}

function isRecoveryAmrMethod(method: unknown): boolean {
  return typeof method === "string" && RECOVERY_AMR_METHOD_SET.has(method);
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null;
}
