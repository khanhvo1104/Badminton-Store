import {
  PRODUCT_SAVE_SUCCESS_MESSAGE,
  PRODUCT_SUCCESS_CREATED,
  PRODUCT_SUCCESS_UPDATED,
} from "@/features/products/constants";

export function productSuccessMessage(
  status: string | string[] | undefined,
): string | null {
  const value = Array.isArray(status) ? status[0] : status;
  switch (value) {
    case PRODUCT_SUCCESS_CREATED:
      return "Product created.";
    case PRODUCT_SUCCESS_UPDATED:
      return PRODUCT_SAVE_SUCCESS_MESSAGE;
    default:
      return null;
  }
}
