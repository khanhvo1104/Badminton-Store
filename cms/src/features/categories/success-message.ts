import {
  CATEGORY_ACTIVATION_SUCCESS_ACTIVE,
  CATEGORY_ACTIVATION_SUCCESS_INACTIVE,
  CATEGORY_SAVE_SUCCESS_MESSAGE,
  CATEGORY_SUCCESS_ACTIVATED,
  CATEGORY_SUCCESS_CREATED,
  CATEGORY_SUCCESS_DEACTIVATED,
  CATEGORY_SUCCESS_UPDATED,
} from "@/features/categories/constants";

export function categorySuccessMessage(
  status: string | string[] | undefined,
): string | null {
  const value = Array.isArray(status) ? status[0] : status;
  switch (value) {
    case CATEGORY_SUCCESS_CREATED:
      return "Category created.";
    case CATEGORY_SUCCESS_UPDATED:
      return CATEGORY_SAVE_SUCCESS_MESSAGE;
    case CATEGORY_SUCCESS_ACTIVATED:
      return CATEGORY_ACTIVATION_SUCCESS_ACTIVE;
    case CATEGORY_SUCCESS_DEACTIVATED:
      return CATEGORY_ACTIVATION_SUCCESS_INACTIVE;
    default:
      return null;
  }
}
