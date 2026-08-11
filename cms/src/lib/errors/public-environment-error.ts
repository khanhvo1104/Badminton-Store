export const USER_FACING_CONFIGURATION_TITLE = "Configuration unavailable";
export const USER_FACING_CONFIGURATION_DESCRIPTION =
  "This CMS foundation cannot start until its public configuration is set correctly. Check the documented setup steps and restart the application.";

export type PublicEnvironmentErrorCode =
  | "missing-url"
  | "invalid-url"
  | "missing-publishable-key";

export class PublicEnvironmentError extends Error {
  readonly code: PublicEnvironmentErrorCode;
  readonly title = USER_FACING_CONFIGURATION_TITLE;
  readonly description = USER_FACING_CONFIGURATION_DESCRIPTION;

  constructor(code: PublicEnvironmentErrorCode) {
    super("Invalid public environment configuration.");
    this.name = "PublicEnvironmentError";
    this.code = code;
  }
}

export function isPublicEnvironmentError(
  error: unknown,
): error is PublicEnvironmentError {
  if (!(error instanceof Error)) {
    return false;
  }

  return (
    error.name === "PublicEnvironmentError" ||
    error.message === "Invalid public environment configuration."
  );
}
