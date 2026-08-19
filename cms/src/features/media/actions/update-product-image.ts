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
  PRODUCT_IMAGE_LIST_COLUMNS,
  PRODUCT_IMAGE_MAX_COUNT,
  SET_CMS_PRODUCT_IMAGE_PRIMARY_RPC,
  productMediaPath,
} from "@/features/media/constants";
import { toMediaMutationFailureMessage } from "@/features/media/errors";
import {
  parseUpdateMediaFormInput,
  readUpdateMediaFormValues,
} from "@/features/media/form-state";
import {
  mapProductImageRow,
  readPrimaryImageId,
} from "@/features/media/mappers";
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
    const listed = await auth.supabase
      .from("product_images")
      .select(PRODUCT_IMAGE_LIST_COLUMNS)
      .eq("product_id", productId)
      .order("sort_order", { ascending: true })
      .order("id", { ascending: true })
      .limit(PRODUCT_IMAGE_MAX_COUNT + 1);

    if (listed.error || !Array.isArray(listed.data)) {
      return errorState(parsed.values, MEDIA_GENERIC_FAILURE_MESSAGE);
    }

    const rows = [];
    for (const value of listed.data) {
      const mapped = mapProductImageRow(value);
      if (!mapped || mapped.product_id !== productId) {
        return errorState(parsed.values, MEDIA_GENERIC_FAILURE_MESSAGE);
      }
      rows.push(mapped);
    }

    const current = rows.find((row) => row.id === imageId);
    if (!current) {
      return errorState(parsed.values, MEDIA_NOT_FOUND_MESSAGE);
    }

    if (parsed.data.variantId) {
      const variantLookup = await auth.supabase
        .from("product_variants")
        .select("id, product_id")
        .eq("id", parsed.data.variantId)
        .maybeSingle();
      if (variantLookup.error) {
        return errorState(parsed.values, MEDIA_GENERIC_FAILURE_MESSAGE);
      }
      const variantRow = variantLookup.data as {
        id?: unknown;
        product_id?: unknown;
      } | null;
      if (variantRow === null || variantRow.product_id !== productId) {
        return errorState(parsed.values, MEDIA_VARIANT_INVALID_MESSAGE, {
          variantId: MEDIA_VARIANT_INVALID_MESSAGE,
        });
      }
    }

    const variantChanged = current.variant_id !== parsed.data.variantId;
    const destinationHasPrimary = rows.some(
      (row) =>
        row.id !== imageId &&
        row.variant_id === parsed.data.variantId &&
        row.is_primary,
    );
    const nextPrimary =
      variantChanged && current.is_primary ? false : current.is_primary;

    const { error } = await auth.supabase
      .from("product_images")
      .update({
        alt_text: parsed.data.altText,
        variant_id: parsed.data.variantId,
        sort_order: parsed.data.sortOrder,
        is_primary: nextPrimary && !destinationHasPrimary,
      })
      .eq("id", imageId)
      .eq("product_id", productId);

    if (error) {
      return errorState(parsed.values, toMediaMutationFailureMessage(error));
    }

    if (variantChanged && current.is_primary) {
      const oldScopeNext = rows.find(
        (row) =>
          row.id !== imageId &&
          row.variant_id === current.variant_id &&
          !row.is_primary,
      );
      if (oldScopeNext) {
        const primaryResult = await auth.supabase.rpc(
          SET_CMS_PRODUCT_IMAGE_PRIMARY_RPC,
          {
            p_product_id: productId,
            p_image_id: oldScopeNext.id,
          },
        );
        if (
          primaryResult.error ||
          !readPrimaryImageId(primaryResult.data, oldScopeNext.id)
        ) {
          return errorState(parsed.values, MEDIA_GENERIC_FAILURE_MESSAGE);
        }
      }
    }

    if (variantChanged && !destinationHasPrimary) {
      const primaryResult = await auth.supabase.rpc(
        SET_CMS_PRODUCT_IMAGE_PRIMARY_RPC,
        {
          p_product_id: productId,
          p_image_id: imageId,
        },
      );
      if (
        primaryResult.error ||
        !readPrimaryImageId(primaryResult.data, imageId)
      ) {
        return errorState(parsed.values, MEDIA_GENERIC_FAILURE_MESSAGE);
      }
    }
  } catch {
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
