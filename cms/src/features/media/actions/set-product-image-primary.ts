"use server";

import { redirect } from "next/navigation";

import {
  mediaDeniedMessage,
  requireMediaActionAuth,
} from "@/features/media/action-utils";
import {
  MEDIA_GENERIC_FAILURE_MESSAGE,
  MEDIA_NOT_FOUND_MESSAGE,
  MEDIA_SUCCESS_PRIMARY,
  SET_CMS_PRODUCT_IMAGE_PRIMARY_RPC,
  productMediaPath,
} from "@/features/media/constants";
import {
  isInvalidRequestError,
  isNotFoundError,
} from "@/features/media/errors";
import { readPrimaryImageId } from "@/features/media/mappers";
import { revalidateMediaPaths } from "@/features/media/revalidate";
import type { PrimaryMediaFormState } from "@/features/media/types";
import { isValidUuid } from "@/features/media/validation";

function errorState(message: string): PrimaryMediaFormState {
  return { status: "error", message, fieldErrors: {} };
}

export async function setProductImagePrimary(
  productId: string,
  imageId: string,
  previousState: PrimaryMediaFormState,
  formData: FormData,
): Promise<PrimaryMediaFormState> {
  void previousState;
  void formData.get("product_id");
  void formData.get("image_id");
  const auth = await requireMediaActionAuth();
  if (!auth.ok) {
    return errorState(mediaDeniedMessage(auth.denied));
  }

  if (!isValidUuid(productId) || !isValidUuid(imageId)) {
    return errorState(MEDIA_NOT_FOUND_MESSAGE);
  }

  try {
    const { data, error } = await auth.supabase.rpc(
      SET_CMS_PRODUCT_IMAGE_PRIMARY_RPC,
      {
        p_product_id: productId,
        p_image_id: imageId,
      },
    );
    if (error) {
      if (isNotFoundError(error)) {
        return errorState(MEDIA_NOT_FOUND_MESSAGE);
      }
      if (isInvalidRequestError(error)) {
        return errorState(MEDIA_NOT_FOUND_MESSAGE);
      }
      return errorState(MEDIA_GENERIC_FAILURE_MESSAGE);
    }
    if (!readPrimaryImageId(data, imageId)) {
      return errorState(MEDIA_GENERIC_FAILURE_MESSAGE);
    }
  } catch {
    return errorState(MEDIA_GENERIC_FAILURE_MESSAGE);
  }

  revalidateMediaPaths(productId);
  redirect(`${productMediaPath(productId)}?success=${MEDIA_SUCCESS_PRIMARY}`);
}
