"use server";

import { redirect } from "next/navigation";

import {
  mediaDeniedMessage,
  requireMediaActionAuth,
} from "@/features/media/action-utils";
import {
  MEDIA_COUNT_LIMIT_MESSAGE,
  MEDIA_GENERIC_FAILURE_MESSAGE,
  MEDIA_NOT_FOUND_MESSAGE,
  MEDIA_PRODUCT_NOT_FOUND_MESSAGE,
  MEDIA_SUCCESS_UPLOADED,
  MEDIA_VARIANT_INVALID_MESSAGE,
  PRODUCT_IMAGE_LIST_COLUMNS,
  PRODUCT_IMAGE_MAX_COUNT,
  SET_CMS_PRODUCT_IMAGE_PRIMARY_RPC,
  productMediaPath,
} from "@/features/media/constants";
import {
  isNotFoundError,
  toMediaMutationFailureMessage,
} from "@/features/media/errors";
import {
  parseUploadMediaFormInput,
  readUploadMediaFormValues,
} from "@/features/media/form-state";
import { readRequiredProductImageFile } from "@/features/media/image";
import {
  mapProductImageRow,
  readPrimaryImageId,
} from "@/features/media/mappers";
import { revalidateMediaPaths } from "@/features/media/revalidate";
import {
  deleteProductImageObject,
  uploadProductImageObject,
} from "@/features/media/storage";
import type { UploadMediaFormState } from "@/features/media/types";
import {
  isValidUuid,
  variantBelongsToProduct,
} from "@/features/media/validation";

function errorState(
  values: UploadMediaFormState["values"],
  message: string,
  fieldErrors: UploadMediaFormState["fieldErrors"] = {},
): UploadMediaFormState {
  return { status: "error", message, fieldErrors, values };
}

export async function uploadProductImage(
  productId: string,
  _previousState: UploadMediaFormState,
  formData: FormData,
): Promise<UploadMediaFormState> {
  const auth = await requireMediaActionAuth();
  if (!auth.ok) {
    return errorState(
      readUploadMediaFormValues(formData),
      mediaDeniedMessage(auth.denied),
    );
  }

  if (!isValidUuid(productId)) {
    return errorState(
      readUploadMediaFormValues(formData),
      MEDIA_PRODUCT_NOT_FOUND_MESSAGE,
    );
  }

  const parsed = parseUploadMediaFormInput(formData);
  if (!parsed.ok) {
    return errorState(parsed.values, parsed.message, parsed.fieldErrors);
  }

  const fileResult = readRequiredProductImageFile(formData);
  if (!fileResult.ok) {
    return errorState(parsed.values, fileResult.message, {
      image: fileResult.message,
    });
  }

  const existingRows: NonNullable<ReturnType<typeof mapProductImageRow>>[] = [];
  try {
    const productLookup = await auth.supabase
      .from("products")
      .select("id")
      .eq("id", productId)
      .maybeSingle();
    if (productLookup.error) {
      return errorState(parsed.values, MEDIA_GENERIC_FAILURE_MESSAGE);
    }
    if (productLookup.data === null) {
      return errorState(parsed.values, MEDIA_PRODUCT_NOT_FOUND_MESSAGE);
    }

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
    if (listed.data.length >= PRODUCT_IMAGE_MAX_COUNT) {
      return errorState(parsed.values, MEDIA_COUNT_LIMIT_MESSAGE, {
        image: MEDIA_COUNT_LIMIT_MESSAGE,
      });
    }
    for (const value of listed.data) {
      const mapped = mapProductImageRow(value);
      if (!mapped || mapped.product_id !== productId) {
        return errorState(parsed.values, MEDIA_GENERIC_FAILURE_MESSAGE);
      }
      existingRows.push(mapped);
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
      if (
        variantRow === null ||
        variantRow.product_id !== productId ||
        typeof variantRow.id !== "string"
      ) {
        return errorState(parsed.values, MEDIA_VARIANT_INVALID_MESSAGE, {
          variantId: MEDIA_VARIANT_INVALID_MESSAGE,
        });
      }
      if (!variantBelongsToProduct(parsed.data.variantId, [variantRow.id])) {
        return errorState(parsed.values, MEDIA_VARIANT_INVALID_MESSAGE, {
          variantId: MEDIA_VARIANT_INVALID_MESSAGE,
        });
      }
    }
  } catch {
    return errorState(parsed.values, MEDIA_GENERIC_FAILURE_MESSAGE);
  }

  const nextSortOrder =
    existingRows.reduce(
      (max, row) => (row.sort_order > max ? row.sort_order : max),
      -1,
    ) + 1;

  const upload = await uploadProductImageObject({
    supabase: auth.supabase,
    productId,
    image: fileResult.image,
  });
  if (!upload.ok) {
    return errorState(parsed.values, upload.message, { image: upload.message });
  }

  let insertedId: string | null = null;
  try {
    const { data, error } = await auth.supabase
      .from("product_images")
      .insert({
        product_id: productId,
        variant_id: parsed.data.variantId,
        storage_path: upload.storedPath,
        alt_text: parsed.data.altText,
        sort_order: nextSortOrder,
        is_primary: false,
      })
      .select("id")
      .maybeSingle();

    if (error || !data || typeof (data as { id?: unknown }).id !== "string") {
      await deleteProductImageObject({
        supabase: auth.supabase,
        storedOrObjectPath: upload.objectPath,
      });
      return errorState(
        parsed.values,
        error
          ? toMediaMutationFailureMessage(error)
          : MEDIA_GENERIC_FAILURE_MESSAGE,
      );
    }
    insertedId = (data as { id: string }).id;
    if (!isValidUuid(insertedId)) {
      await deleteProductImageObject({
        supabase: auth.supabase,
        storedOrObjectPath: upload.objectPath,
      });
      return errorState(parsed.values, MEDIA_GENERIC_FAILURE_MESSAGE);
    }
  } catch {
    await deleteProductImageObject({
      supabase: auth.supabase,
      storedOrObjectPath: upload.objectPath,
    });
    return errorState(parsed.values, MEDIA_GENERIC_FAILURE_MESSAGE);
  }

  const scopeHasPrimary = existingRows.some(
    (row) => row.variant_id === parsed.data.variantId && row.is_primary,
  );
  if (parsed.data.setPrimary || !scopeHasPrimary) {
    try {
      const { data, error } = await auth.supabase.rpc(
        SET_CMS_PRODUCT_IMAGE_PRIMARY_RPC,
        {
          p_product_id: productId,
          p_image_id: insertedId,
        },
      );
      if (error || !readPrimaryImageId(data, insertedId)) {
        if (isNotFoundError(error)) {
          return errorState(parsed.values, MEDIA_NOT_FOUND_MESSAGE);
        }
        return errorState(parsed.values, MEDIA_GENERIC_FAILURE_MESSAGE);
      }
    } catch {
      return errorState(parsed.values, MEDIA_GENERIC_FAILURE_MESSAGE);
    }
  }

  revalidateMediaPaths(productId);
  redirect(`${productMediaPath(productId)}?success=${MEDIA_SUCCESS_UPLOADED}`);
}
