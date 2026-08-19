"use server";

import { redirect } from "next/navigation";

import {
  mediaDeniedMessage,
  requireMediaActionAuth,
} from "@/features/media/action-utils";
import {
  MEDIA_GENERIC_FAILURE_MESSAGE,
  MEDIA_IMAGE_CLEANUP_WARNING,
  MEDIA_NOT_FOUND_MESSAGE,
  MEDIA_SUCCESS_REPLACED,
  PRODUCT_IMAGE_LIST_COLUMNS,
  productMediaPath,
} from "@/features/media/constants";
import { toMediaMutationFailureMessage } from "@/features/media/errors";
import { readRequiredProductImageFile } from "@/features/media/image";
import { mapProductImageRow } from "@/features/media/mappers";
import { revalidateMediaPaths } from "@/features/media/revalidate";
import {
  deleteProductImageObject,
  uploadProductImageObject,
} from "@/features/media/storage";
import type { ReplaceMediaFormState } from "@/features/media/types";
import { isValidUuid } from "@/features/media/validation";

function errorState(
  message: string,
  fieldErrors: ReplaceMediaFormState["fieldErrors"] = {},
): ReplaceMediaFormState {
  return { status: "error", message, fieldErrors };
}

export async function replaceProductImage(
  productId: string,
  imageId: string,
  _previousState: ReplaceMediaFormState,
  formData: FormData,
): Promise<ReplaceMediaFormState> {
  const auth = await requireMediaActionAuth();
  if (!auth.ok) {
    return errorState(mediaDeniedMessage(auth.denied));
  }

  if (!isValidUuid(productId) || !isValidUuid(imageId)) {
    return errorState(MEDIA_NOT_FOUND_MESSAGE);
  }

  const fileResult = readRequiredProductImageFile(formData);
  if (!fileResult.ok) {
    return errorState(fileResult.message, { image: fileResult.message });
  }

  let existingPath: string | null = null;
  try {
    const { data, error } = await auth.supabase
      .from("product_images")
      .select(PRODUCT_IMAGE_LIST_COLUMNS)
      .eq("id", imageId)
      .eq("product_id", productId)
      .maybeSingle();

    if (error) {
      return errorState(MEDIA_GENERIC_FAILURE_MESSAGE);
    }
    const mapped = mapProductImageRow(data);
    if (!mapped || mapped.product_id !== productId || mapped.id !== imageId) {
      return errorState(MEDIA_NOT_FOUND_MESSAGE);
    }
    existingPath = mapped.storage_path;
  } catch {
    return errorState(MEDIA_GENERIC_FAILURE_MESSAGE);
  }

  const upload = await uploadProductImageObject({
    supabase: auth.supabase,
    productId,
    image: fileResult.image,
  });
  if (!upload.ok) {
    return errorState(upload.message, { image: upload.message });
  }

  try {
    const { error } = await auth.supabase
      .from("product_images")
      .update({ storage_path: upload.storedPath })
      .eq("id", imageId)
      .eq("product_id", productId);

    if (error) {
      await deleteProductImageObject({
        supabase: auth.supabase,
        storedOrObjectPath: upload.objectPath,
      });
      return errorState(toMediaMutationFailureMessage(error));
    }
  } catch {
    await deleteProductImageObject({
      supabase: auth.supabase,
      storedOrObjectPath: upload.objectPath,
    });
    return errorState(MEDIA_GENERIC_FAILURE_MESSAGE);
  }

  let cleanupWarning: string | null = null;
  if (existingPath && existingPath !== upload.storedPath) {
    const cleanup = await deleteProductImageObject({
      supabase: auth.supabase,
      storedOrObjectPath: existingPath,
    });
    if (!cleanup.ok) {
      cleanupWarning = MEDIA_IMAGE_CLEANUP_WARNING;
    }
  }

  revalidateMediaPaths(productId);
  if (cleanupWarning) {
    return {
      status: "success",
      message: cleanupWarning,
      fieldErrors: {},
    };
  }

  redirect(`${productMediaPath(productId)}?success=${MEDIA_SUCCESS_REPLACED}`);
}
