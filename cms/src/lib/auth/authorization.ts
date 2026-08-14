export const CMS_DASHBOARD_PATH = "/dashboard";
export const CMS_LOGIN_PATH = "/login";
export const CMS_UNAUTHORIZED_PATH = "/unauthorized";
export const CMS_FORGOT_PASSWORD_PATH = "/forgot-password";
export const CMS_UPDATE_PASSWORD_PATH = "/update-password";
export const CMS_AUTH_CALLBACK_PATH = "/auth/callback";
export const CMS_PROFILE_COLUMNS = "id, full_name, role, is_active";

export const AUTH_FAILURE_MESSAGE =
  "We couldn't sign you in with those credentials.";

export type CmsAuthorizationResult =
  | { kind: "anonymous" }
  | { kind: "unauthorized" }
  | {
      kind: "authorized";
      profile: {
        id: string;
        fullName: string | null;
        role: "staff" | "admin";
        isActive: true;
      };
    };

type ClaimsResponse = {
  data: {
    claims?: {
      sub?: unknown;
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

export async function getVerifiedSubject(
  supabase: Pick<AuthorizationSupabaseClient, "auth">,
): Promise<string | null> {
  try {
    const { data, error } = await supabase.auth.getClaims();

    if (error) {
      return null;
    }

    const subject = data?.claims?.sub;
    return typeof subject === "string" && subject.trim() ? subject : null;
  } catch {
    return null;
  }
}

export async function authorizeCmsRequest(
  supabase: AuthorizationSupabaseClient,
): Promise<CmsAuthorizationResult> {
  const subject = await getVerifiedSubject(supabase);

  if (!subject) {
    return { kind: "anonymous" };
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

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null;
}
