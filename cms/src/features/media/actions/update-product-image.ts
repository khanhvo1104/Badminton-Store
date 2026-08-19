"use server";

import { redirect } from "next/navigation";

import {
  mediaDeniedMessage,
  requireMediaActionAuth,
} from "@/features/media/action-utils";
import {
  MEDIA_GENERIC_FAILURE_MESSAGE,
  MEDIA_NOT_FOUND_MESSAGE,
  MEDIA_PRODUCT_NOT_FOUND_MESSAGE,
  MEDIA_SUCCESS_UPDATED,
  MEDIA_VARIANT_INVALID_MESSAGE,
  UPDATE_CMS_PRODUCT_IMAGE_RPC,
  productMediaPath,
} from "@/features/media/constants";
import {
  isInvalidVariantError,
  isNotFoundError,
  toMediaMutationFailureMessage,
} from "@/features/media/errors";
import {
  parseUpdateMediaFormInput,
  readUpdateMediaFormValues,
} from "@/features/media/form-state";
import { readPrimaryImageId } from "@/features/media/mappers";
import { revalidateMediaPaths } from "@/features/media/revalidate";
import type { UpdateMediaFormState } from "@/features/media/types";
import { isValidUuid } from "@/features/media/validation";

function errorState(
  values: UpdateMediaFormState["values"],
  message: string,
  fieldErrors: UpdateMediaFormState["fieldErrors"] = {},
): UpdateMediaFormState {
  return { status: "error", message, fieldErrors, values };
}

export async function updateProductImage(
  productId: string,
  imageId: string,
  _previousState: UpdateMediaFormState,
  formData: FormData,
): Promise<UpdateMediaFormState> {
  const auth = await requireMediaActionAuth();
  if (!auth.ok) {
    return errorState(
      readUpdateMediaFormValues(formData),
      mediaDeniedMessage(auth.denied),
    );
  }

  if (!isValidUuid(productId) || !isValidUuid(imageId)) {
    return errorState(
      readUpdateMediaFormValues(formData),
      MEDIA_NOT_FOUND_MESSAGE,
    );
  }

  const parsed = parseUpdateMediaFormInput(formData);
  if (!parsed.ok) {
    return errorState(parsed.values, parsed.message, parsed.fieldErrors);
  }

  try {
    const { data, error } = await auth.supabase.rpc(
      UPDATE_CMS_PRODUCT_IMAGE_RPC,
      {
        p_product_id: productId,
        p_image_id: imageId,
        p_alt_text: parsed.data.altText,
        p_variant_id: parsed.data.variantId,
        p_sort_order: parsed.data.sortOrder,
      },
    );

    if (error || !readPrimaryImageId(data, imageId)) {
      if (isNotFoundError(error)) {
        return errorState(parsed.values, MEDIA_NOT_FOUND_MESSAGE);
      }
      if (isInvalidVariantError(error)) {
        return errorState(parsed.values, MEDIA_VARIANT_INVALID_MESSAGE, {
          variantId: MEDIA_VARIANT_INVALID_MESSAGE,
        });
      }
      return errorState(
        parsed.values,
        error
          ? toMediaMutationFailureMessage(error)
          : MEDIA_GENERIC_FAILURE_MESSAGE,
      );
    }
  } catch (error) {
    if (isNotFoundError(error)) {
      return errorState(parsed.values, MEDIA_NOT_FOUND_MESSAGE);
    }
    if (isInvalidVariantError(error)) {
      return errorState(parsed.values, MEDIA_VARIANT_INVALID_MESSAGE, {
        variantId: MEDIA_VARIANT_INVALID_MESSAGE,
      });
    }
    return errorState(
      parsed.values,
      isValidUuid(productId)
        ? MEDIA_GENERIC_FAILURE_MESSAGE
        : MEDIA_PRODUCT_NOT_FOUND_MESSAGE,
    );
  }

  revalidateMediaPaths(productId);
  redirect(`${productMediaPath(productId)}?success=${MEDIA_SUCCESS_UPDATED}`);
}
