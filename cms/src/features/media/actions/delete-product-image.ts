"use server";

import { redirect } from "next/navigation";

import {
  mediaDeniedMessage,
  requireMediaActionAuth,
} from "@/features/media/action-utils";
import {
  MEDIA_DELETE_CLEANUP_WARNING,
  MEDIA_DELETE_CONFIRM_REQUIRED_MESSAGE,
  MEDIA_GENERIC_FAILURE_MESSAGE,
  MEDIA_NOT_FOUND_MESSAGE,
  MEDIA_SUCCESS_DELETED,
  PRODUCT_IMAGE_LIST_COLUMNS,
  PRODUCT_IMAGE_MAX_COUNT,
  SET_CMS_PRODUCT_IMAGE_PRIMARY_RPC,
  productMediaPath,
} from "@/features/media/constants";
import { toMediaMutationFailureMessage } from "@/features/media/errors";
import {
  mapProductImageRow,
  readPrimaryImageId,
} from "@/features/media/mappers";
import { revalidateMediaPaths } from "@/features/media/revalidate";
import { deleteProductImageObject } from "@/features/media/storage";
import type { DeleteMediaFormState } from "@/features/media/types";
import { isValidUuid, parseCheckboxFlag } from "@/features/media/validation";

function errorState(
  message: string,
  fieldErrors: DeleteMediaFormState["fieldErrors"] = {},
): DeleteMediaFormState {
  return { status: "error", message, fieldErrors };
}

export async function deleteProductImage(
  productId: string,
  imageId: string,
  _previousState: DeleteMediaFormState,
  formData: FormData,
): Promise<DeleteMediaFormState> {
  if (!parseCheckboxFlag(formData.get("confirmed"))) {
    return errorState(MEDIA_DELETE_CONFIRM_REQUIRED_MESSAGE, {
      confirmed: MEDIA_DELETE_CONFIRM_REQUIRED_MESSAGE,
    });
  }

  const auth = await requireMediaActionAuth();
  if (!auth.ok) {
    return errorState(mediaDeniedMessage(auth.denied));
  }

  if (!isValidUuid(productId) || !isValidUuid(imageId)) {
    return errorState(MEDIA_NOT_FOUND_MESSAGE);
  }

  let storedPath: string | null = null;
  let wasPrimary = false;
  let nextPrimaryId: string | null = null;

  try {
    const listed = await auth.supabase
      .from("product_images")
      .select(PRODUCT_IMAGE_LIST_COLUMNS)
      .eq("product_id", productId)
      .order("sort_order", { ascending: true })
      .order("id", { ascending: true })
      .limit(PRODUCT_IMAGE_MAX_COUNT + 1);

    if (listed.error || !Array.isArray(listed.data)) {
      return errorState(MEDIA_GENERIC_FAILURE_MESSAGE);
    }

    const rows = [];
    for (const value of listed.data) {
      const mapped = mapProductImageRow(value);
      if (!mapped || mapped.product_id !== productId) {
        return errorState(MEDIA_GENERIC_FAILURE_MESSAGE);
      }
      rows.push(mapped);
    }

    const current = rows.find((row) => row.id === imageId);
    if (!current) {
      return errorState(MEDIA_NOT_FOUND_MESSAGE);
    }

    storedPath = current.storage_path;
    wasPrimary = current.is_primary;
    if (wasPrimary) {
      const next = rows.find(
        (row) => row.id !== imageId && row.variant_id === current.variant_id,
      );
      nextPrimaryId = next?.id ?? null;
    }

    if (wasPrimary && nextPrimaryId) {
      const { data, error } = await auth.supabase.rpc(
        SET_CMS_PRODUCT_IMAGE_PRIMARY_RPC,
        {
          p_product_id: productId,
          p_image_id: nextPrimaryId,
        },
      );
      if (error || !readPrimaryImageId(data, nextPrimaryId)) {
        return errorState(MEDIA_GENERIC_FAILURE_MESSAGE);
      }
    }

    const { error } = await auth.supabase
      .from("product_images")
      .delete()
      .eq("id", imageId)
      .eq("product_id", productId);

    if (error) {
      return errorState(toMediaMutationFailureMessage(error));
    }
  } catch {
    return errorState(MEDIA_GENERIC_FAILURE_MESSAGE);
  }

  let cleanupWarning: string | null = null;
  if (storedPath) {
    const cleanup = await deleteProductImageObject({
      supabase: auth.supabase,
      storedOrObjectPath: storedPath,
    });
    if (!cleanup.ok) {
      cleanupWarning = MEDIA_DELETE_CLEANUP_WARNING;
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

  redirect(`${productMediaPath(productId)}?success=${MEDIA_SUCCESS_DELETED}`);
}
