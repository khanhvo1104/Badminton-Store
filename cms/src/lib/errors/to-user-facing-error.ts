import {
  isPublicEnvironmentError,
  USER_FACING_CONFIGURATION_DESCRIPTION,
  USER_FACING_CONFIGURATION_TITLE,
} from "@/lib/errors/public-environment-error";

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
  if (isPublicEnvironmentError(error)) {
    return {
      title: USER_FACING_CONFIGURATION_TITLE,
      description: USER_FACING_CONFIGURATION_DESCRIPTION,
    };
  }

  return FALLBACK_ERROR;
}
