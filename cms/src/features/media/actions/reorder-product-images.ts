"use server";

import { redirect } from "next/navigation";

import {
  mediaDeniedMessage,
  requireMediaActionAuth,
} from "@/features/media/action-utils";
import {
  MEDIA_GENERIC_FAILURE_MESSAGE,
  MEDIA_PRODUCT_NOT_FOUND_MESSAGE,
  MEDIA_REORDER_INVALID_MESSAGE,
  MEDIA_SUCCESS_REORDERED,
  PRODUCT_IMAGE_LIST_COLUMNS,
  PRODUCT_IMAGE_MAX_COUNT,
  REORDER_CMS_PRODUCT_IMAGES_RPC,
  productMediaPath,
} from "@/features/media/constants";
import {
  isInvalidRequestError,
  isNotFoundError,
} from "@/features/media/errors";
import {
  mapProductImageRow,
  readReorderedProductId,
} from "@/features/media/mappers";
import { revalidateMediaPaths } from "@/features/media/revalidate";
import type { ReorderMediaFormState } from "@/features/media/types";
import { isValidUuid, parseReorderImageIds } from "@/features/media/validation";

function errorState(
  message: string,
  fieldErrors: ReorderMediaFormState["fieldErrors"] = {},
): ReorderMediaFormState {
  return { status: "error", message, fieldErrors };
}

export async function reorderProductImages(
  productId: string,
  _previousState: ReorderMediaFormState,
  formData: FormData,
): Promise<ReorderMediaFormState> {
  const auth = await requireMediaActionAuth();
  if (!auth.ok) {
    return errorState(mediaDeniedMessage(auth.denied));
  }

  if (!isValidUuid(productId)) {
    return errorState(MEDIA_PRODUCT_NOT_FOUND_MESSAGE);
  }

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
    if (listed.data.length > PRODUCT_IMAGE_MAX_COUNT) {
      return errorState(MEDIA_GENERIC_FAILURE_MESSAGE);
    }

    const currentIds: string[] = [];
    for (const value of listed.data) {
      const mapped = mapProductImageRow(value);
      if (!mapped || mapped.product_id !== productId) {
        return errorState(MEDIA_GENERIC_FAILURE_MESSAGE);
      }
      currentIds.push(mapped.id);
    }

    const parsed = parseReorderImageIds(formData, currentIds.length);
    if (!parsed.ok) {
      return errorState(parsed.message, { imageIds: parsed.message });
    }

    const currentSet = new Set(currentIds);
    if (
      parsed.imageIds.length !== currentIds.length ||
      parsed.imageIds.some((id) => !currentSet.has(id))
    ) {
      return errorState(MEDIA_REORDER_INVALID_MESSAGE, {
        imageIds: MEDIA_REORDER_INVALID_MESSAGE,
      });
    }

    const { data, error } = await auth.supabase.rpc(
      REORDER_CMS_PRODUCT_IMAGES_RPC,
      {
        p_product_id: productId,
        p_image_ids: parsed.imageIds,
      },
    );
    if (error) {
      if (isNotFoundError(error)) {
        return errorState(MEDIA_PRODUCT_NOT_FOUND_MESSAGE);
      }
      if (isInvalidRequestError(error)) {
        return errorState(MEDIA_REORDER_INVALID_MESSAGE, {
          imageIds: MEDIA_REORDER_INVALID_MESSAGE,
        });
      }
      return errorState(MEDIA_GENERIC_FAILURE_MESSAGE);
    }
    if (!readReorderedProductId(data, productId)) {
      return errorState(MEDIA_GENERIC_FAILURE_MESSAGE);
    }
  } catch {
    return errorState(MEDIA_GENERIC_FAILURE_MESSAGE);
  }

  revalidateMediaPaths(productId);
  redirect(`${productMediaPath(productId)}?success=${MEDIA_SUCCESS_REORDERED}`);
}
