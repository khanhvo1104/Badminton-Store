import {
  VARIANT_SAVE_SUCCESS_MESSAGE,
  VARIANT_SUCCESS_CREATED,
  VARIANT_SUCCESS_UPDATED,
} from "@/features/variants/constants";

export function variantSuccessMessage(
  status: string | string[] | undefined,
): string | null {
  const value = Array.isArray(status) ? status[0] : status;
  switch (value) {
    case VARIANT_SUCCESS_CREATED:
      return "Variant created.";
    case VARIANT_SUCCESS_UPDATED:
      return VARIANT_SAVE_SUCCESS_MESSAGE;
    default:
      return null;
  }
}
