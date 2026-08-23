export const AUTH_DENIED_MESSAGE =
  "You don't have permission to invite staff members.";
export const GENERIC_FAILURE_MESSAGE =
  "We couldn't send that invitation. Try again later.";
export const INVALID_REQUEST_MESSAGE =
  "Check the email address and role, then try again.";
export const RATE_LIMIT_MESSAGE =
  "Email sending is temporarily limited. Wait a few minutes and try again, or ask your operator to review SMTP rate limits.";
export const DUPLICATE_MESSAGE =
  "That email already belongs to an account. Update the existing staff member instead of sending a new invitation.";

export const FINALIZE_CMS_STAFF_INVITATION_RPC = "finalize_cms_staff_invitation";

const EMAIL_PATTERN = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

export function readEmail(value: unknown): string | null {
  if (typeof value !== "string") {
    return null;
  }
  const normalized = value.trim().toLowerCase();
  if (
    !normalized ||
    normalized.length > 254 ||
    !EMAIL_PATTERN.test(normalized)
  ) {
    return null;
  }
  return normalized;
}

export function readRole(value: unknown): "staff" | "admin" | null {
  if (value !== "staff" && value !== "admin") {
    return null;
  }
  return value;
}

export function readFullName(value: unknown): string | null {
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

export function buildInviteRedirectTo(rawSiteUrl: string): string | null {
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

export function mapInviteError(error: {
  message?: string;
  status?: number;
}): string {
  const message =
    typeof error.message === "string" ? error.message.toLowerCase() : "";
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

export function mapInviteStatus(error: {
  message?: string;
  status?: number;
}): number {
  const message =
    typeof error.message === "string" ? error.message.toLowerCase() : "";
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

export function readSubject(claims: unknown): string | null {
  if (!isRecord(claims)) {
    return null;
  }
  const subject = claims.sub;
  return typeof subject === "string" && subject.trim() ? subject : null;
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null;
}
