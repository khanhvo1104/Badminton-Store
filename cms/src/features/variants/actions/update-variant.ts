"use server";

import { redirect } from "next/navigation";

import {
  denialState,
  errorState,
  requireVariantActionAuth,
} from "@/features/variants/action-utils";
import {
  VARIANT_GENERIC_FAILURE_MESSAGE,
  VARIANT_NOT_FOUND_MESSAGE,
  VARIANT_PRODUCT_NOT_FOUND_MESSAGE,
  VARIANT_SUCCESS_UPDATED,
  productVariantEditPath,
  SAVE_CMS_PRODUCT_VARIANT_RPC,
  VARIANT_SAFE_COLUMNS,
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
import {
  mapVariantSafeRow,
  readSavedVariantId,
} from "@/features/variants/mappers";
import { revalidateVariantPaths } from "@/features/variants/revalidate";
import type { VariantFormState } from "@/features/variants/types";
import { isValidUuid } from "@/features/products/validation";

export async function updateVariant(
  productId: string,
  variantId: string,
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
  if (!isValidUuid(variantId)) {
    return errorState(
      preserveSafeVariantValues(readVariantFormValues(formData)),
      VARIANT_NOT_FOUND_MESSAGE,
    );
  }

  let currentIsDefault = false;
  try {
    const { data, error } = await auth.supabase
      .from("product_variants")
      .select(VARIANT_SAFE_COLUMNS)
      .eq("id", variantId)
      .eq("product_id", productId)
      .maybeSingle();

    if (error) {
      return errorState(
        preserveSafeVariantValues(readVariantFormValues(formData)),
        VARIANT_GENERIC_FAILURE_MESSAGE,
      );
    }
    if (data === null) {
      return errorState(
        preserveSafeVariantValues(readVariantFormValues(formData)),
        VARIANT_NOT_FOUND_MESSAGE,
      );
    }
    const row = mapVariantSafeRow(data);
    if (!row) {
      return errorState(
        preserveSafeVariantValues(readVariantFormValues(formData)),
        VARIANT_GENERIC_FAILURE_MESSAGE,
      );
    }
    currentIsDefault = row.is_default;
  } catch {
    return errorState(
      preserveSafeVariantValues(readVariantFormValues(formData)),
      VARIANT_GENERIC_FAILURE_MESSAGE,
    );
  }

  const parsed = parseVariantFormInput(formData, {
    mode: "edit",
    currentIsDefault,
  });
  if (!parsed.ok) {
    return errorState(parsed.values, parsed.message, parsed.fieldErrors);
  }

  const args = buildVariantMutationArgs({
    productId,
    variantId,
    data: parsed.data,
  });

  try {
    const { data, error } = await auth.supabase.rpc(
      SAVE_CMS_PRODUCT_VARIANT_RPC,
      args,
    );
    if (error) {
      if (isNotFoundError(error)) {
        return errorState(parsed.values, VARIANT_NOT_FOUND_MESSAGE);
      }
      const message = toVariantMutationFailureMessage(error);
      return errorState(
        parsed.values,
        message,
        variantMutationFieldErrors(error, message),
      );
    }
    const savedId = readSavedVariantId(data);
    if (!savedId) {
      return errorState(parsed.values, VARIANT_GENERIC_FAILURE_MESSAGE);
    }
  } catch {
    return errorState(parsed.values, VARIANT_GENERIC_FAILURE_MESSAGE);
  }

  revalidateVariantPaths(productId, variantId);
  redirect(
    `${productVariantEditPath(productId, variantId)}?success=${VARIANT_SUCCESS_UPDATED}`,
  );
}
