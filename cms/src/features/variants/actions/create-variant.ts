"use server";

import { redirect } from "next/navigation";

import {
  denialState,
  errorState,
  requireVariantActionAuth,
} from "@/features/variants/action-utils";
import {
  VARIANT_GENERIC_FAILURE_MESSAGE,
  VARIANT_PRODUCT_NOT_FOUND_MESSAGE,
  VARIANT_SUCCESS_CREATED,
  productVariantEditPath,
  SAVE_CMS_PRODUCT_VARIANT_RPC,
} from "@/features/variants/constants";
import {
  isNotFoundError,
  toVariantMutationFailureMessage,
  variantMutationFieldErrors,
} from "@/features/variants/errors";
import {
  buildVariantMutationArgs,
  parseVariantFormInput,
  preserveSafeVariantValues,
  readVariantFormValues,
} from "@/features/variants/form-validation";
import { readSavedVariantId } from "@/features/variants/mappers";
import { revalidateVariantPaths } from "@/features/variants/revalidate";
import type { VariantFormState } from "@/features/variants/types";
import { isValidUuid } from "@/features/products/validation";

export async function createVariant(
  productId: string,
  _previousState: VariantFormState,
  formData: FormData,
): Promise<VariantFormState> {
  const auth = await requireVariantActionAuth();
  if (!auth.ok) {
    return denialState(
      preserveSafeVariantValues(readVariantFormValues(formData)),
    );
  }

  if (!isValidUuid(productId)) {
    return errorState(
      preserveSafeVariantValues(readVariantFormValues(formData)),
      VARIANT_PRODUCT_NOT_FOUND_MESSAGE,
    );
  }

  const parsed = parseVariantFormInput(formData, { mode: "create" });
  if (!parsed.ok) {
    return errorState(parsed.values, parsed.message, parsed.fieldErrors);
  }

  const args = buildVariantMutationArgs({
    productId,
    variantId: null,
    data: parsed.data,
  });

  let savedId: string;
  try {
    const { data, error } = await auth.supabase.rpc(
      SAVE_CMS_PRODUCT_VARIANT_RPC,
      args,
    );
    if (error) {
      if (isNotFoundError(error)) {
        return errorState(parsed.values, VARIANT_PRODUCT_NOT_FOUND_MESSAGE);
      }
      const message = toVariantMutationFailureMessage(error);
      return errorState(
        parsed.values,
        message,
        variantMutationFieldErrors(error, message),
      );
    }
    const variantId = readSavedVariantId(data);
    if (!variantId) {
      return errorState(parsed.values, VARIANT_GENERIC_FAILURE_MESSAGE);
    }
    savedId = variantId;
  } catch {
    return errorState(parsed.values, VARIANT_GENERIC_FAILURE_MESSAGE);
  }

  revalidateVariantPaths(productId, savedId);
  redirect(
    `${productVariantEditPath(productId, savedId)}?success=${VARIANT_SUCCESS_CREATED}`,
  );
}
