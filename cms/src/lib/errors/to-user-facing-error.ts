import { PublicEnvironmentError } from "@/lib/errors/public-environment-error";

export type UserFacingError = {
  title: string;
  description: string;
};

const FALLBACK_ERROR: UserFacingError = {
  title: "Something went wrong",
  description:
    "The CMS foundation hit an unexpected issue. Reload the page or review the local setup instructions before trying again.",
};

export function toUserFacingError(error: unknown): UserFacingError {
  if (error instanceof PublicEnvironmentError) {
    return {
      title: error.title,
      description: error.description,
    };
  }

  return FALLBACK_ERROR;
}
