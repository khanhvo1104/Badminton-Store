import {
  CMS_AUTH_CALLBACK_PATH,
  CMS_LOGIN_PATH,
  CMS_UPDATE_PASSWORD_PATH,
} from "@/lib/auth/authorization";

export { isVerifiedRecoverySession } from "@/lib/auth/authorization";

export const PASSWORD_RECOVERY_ACKNOWLEDGEMENT =
  "If an account exists for that email, we sent password recovery instructions.";

export const EMAIL_VALIDATION_MESSAGE = "Enter a valid email address.";

export const PASSWORD_UPDATED_MESSAGE =
  "Your password was updated. Sign in with your new password.";

export const PASSWORD_RECOVERY_FAILED_MESSAGE =
  "We couldn't complete password recovery. Request a new reset email and try again.";

export const PASSWORD_UPDATE_FAILED_MESSAGE =
  "We couldn't update your password. Try again.";

export const PASSWORD_TOO_WEAK_MESSAGE =
  "Choose a password with at least 12 characters.";

export const PASSWORD_CONFIRMATION_MISMATCH_MESSAGE =
  "Password and confirmation must match.";

export const LOGIN_STATUS_PASSWORD_UPDATED = "password-updated";
export const LOGIN_STATUS_RECOVERY_FAILED = "recovery-failed";

export const MIN_PASSWORD_LENGTH = 12;

const EMAIL_PATTERN = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
const PKCE_CODE_PATTERN = /^[A-Za-z0-9._~-]{16,2048}$/;
const ALLOWED_POST_AUTH_PATHS = new Set<string>([CMS_UPDATE_PASSWORD_PATH]);

export function isSyntacticallyValidEmail(value: string): boolean {
  return EMAIL_PATTERN.test(value) && value.length <= 254;
}

export function isPkceAuthCode(
  value: string | null | undefined,
): value is string {
  return typeof value === "string" && PKCE_CODE_PATTERN.test(value);
}

export function resolveSafePostAuthPath(
  next: string | null | undefined,
): string {
  if (typeof next !== "string") {
    return CMS_UPDATE_PASSWORD_PATH;
  }

  if (!ALLOWED_POST_AUTH_PATHS.has(next)) {
    return CMS_UPDATE_PASSWORD_PATH;
  }

  return next;
}

export function getPasswordRecoveryRedirectTo(siteUrl: URL): string {
  const callbackUrl = new URL(CMS_AUTH_CALLBACK_PATH, siteUrl);
  callbackUrl.searchParams.set("next", CMS_UPDATE_PASSWORD_PATH);
  return callbackUrl.toString();
}

export function getLoginRedirectPath(status?: string): string {
  if (!status) {
    return CMS_LOGIN_PATH;
  }

  if (
    status !== LOGIN_STATUS_PASSWORD_UPDATED &&
    status !== LOGIN_STATUS_RECOVERY_FAILED
  ) {
    return CMS_LOGIN_PATH;
  }

  return `${CMS_LOGIN_PATH}?status=${status}`;
}

export function readLoginStatus(
  value: string | string[] | undefined,
): string | null {
  if (typeof value !== "string") {
    return null;
  }

  if (
    value === LOGIN_STATUS_PASSWORD_UPDATED ||
    value === LOGIN_STATUS_RECOVERY_FAILED
  ) {
    return value;
  }

  return null;
}

export function validateNewPassword(
  password: string,
  confirmation: string,
): string | null {
  if (password.length < MIN_PASSWORD_LENGTH) {
    return PASSWORD_TOO_WEAK_MESSAGE;
  }

  if (password !== confirmation) {
    return PASSWORD_CONFIRMATION_MISMATCH_MESSAGE;
  }

  return null;
}
