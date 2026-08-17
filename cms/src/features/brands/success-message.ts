import {
  BRAND_ACTIVATION_SUCCESS_ACTIVE,
  BRAND_ACTIVATION_SUCCESS_INACTIVE,
  BRAND_SAVE_SUCCESS_MESSAGE,
  BRAND_SUCCESS_ACTIVATED,
  BRAND_SUCCESS_CREATED,
  BRAND_SUCCESS_DEACTIVATED,
  BRAND_SUCCESS_UPDATED,
} from "@/features/brands/constants";

export function brandSuccessMessage(
  status: string | string[] | undefined,
): string | null {
  const value = Array.isArray(status) ? status[0] : status;
  switch (value) {
    case BRAND_SUCCESS_CREATED:
      return "Brand created.";
    case BRAND_SUCCESS_UPDATED:
      return BRAND_SAVE_SUCCESS_MESSAGE;
    case BRAND_SUCCESS_ACTIVATED:
      return BRAND_ACTIVATION_SUCCESS_ACTIVE;
    case BRAND_SUCCESS_DEACTIVATED:
      return BRAND_ACTIVATION_SUCCESS_INACTIVE;
    default:
      return null;
  }
}
