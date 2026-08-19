"use server";

import { redirect } from "next/navigation";

import {
  mediaDeniedMessage,
  requireMediaActionAuth,
} from "@/features/media/action-utils";
import {
  INSERT_CMS_PRODUCT_IMAGE_RPC,
  MEDIA_COUNT_LIMIT_MESSAGE,
  MEDIA_GENERIC_FAILURE_MESSAGE,
  MEDIA_PRODUCT_NOT_FOUND_MESSAGE,
  MEDIA_SUCCESS_UPLOADED,
  MEDIA_VARIANT_INVALID_MESSAGE,
  PRODUCT_IMAGE_LIST_COLUMNS,
  PRODUCT_IMAGE_MAX_COUNT,
  productMediaPath,
} from "@/features/media/constants";
import {
  isImageLimitError,
  isInvalidVariantError,
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
  readReturnedImageId,
} from "@/features/media/mappers";
import { revalidateMediaPaths } from "@/features/media/revalidate";
import {
  deleteProductImageObject,
  uploadProductImageObject,
} from "@/features/media/storage";
import type { UploadMediaFormState } from "@/features/media/types";
import { isValidUuid } from "@/features/media/validation";

function errorState(
  values: UploadMediaFormState["values"],
  message: string,
  fieldErrors: UploadMediaFormState["fieldErrors"] = {},
): UploadMediaFormState {
  return { status: "error", message, fieldErrors, values };
}

function uploadRpcFailure(
  values: UploadMediaFormState["values"],
  error: unknown,
): UploadMediaFormState {
  if (isNotFoundError(error)) {
    return errorState(values, MEDIA_PRODUCT_NOT_FOUND_MESSAGE);
  }
  if (isImageLimitError(error)) {
    return errorState(values, MEDIA_COUNT_LIMIT_MESSAGE, {
      image: MEDIA_COUNT_LIMIT_MESSAGE,
    });
  }
  if (isInvalidVariantError(error)) {
    return errorState(values, MEDIA_VARIANT_INVALID_MESSAGE, {
      variantId: MEDIA_VARIANT_INVALID_MESSAGE,
    });
  }
  return errorState(values, toMediaMutationFailureMessage(error));
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
    }
  } catch {
    return errorState(parsed.values, MEDIA_GENERIC_FAILURE_MESSAGE);
  }

  const upload = await uploadProductImageObject({
    supabase: auth.supabase,
    productId,
    image: fileResult.image,
  });
  if (!upload.ok) {
    return errorState(parsed.values, upload.message, { image: upload.message });
  }

  try {
    const { data, error } = await auth.supabase.rpc(
      INSERT_CMS_PRODUCT_IMAGE_RPC,
      {
        p_product_id: productId,
        p_storage_path: upload.storedPath,
        p_alt_text: parsed.data.altText,
        p_variant_id: parsed.data.variantId,
        p_set_primary: parsed.data.setPrimary,
      },
    );
    if (error || !readReturnedImageId(data)) {
      await deleteProductImageObject({
        supabase: auth.supabase,
        storedOrObjectPath: upload.objectPath,
      });
      if (error) {
        return uploadRpcFailure(parsed.values, error);
      }
      return errorState(parsed.values, MEDIA_GENERIC_FAILURE_MESSAGE);
    }
  } catch (error) {
    await deleteProductImageObject({
      supabase: auth.supabase,
      storedOrObjectPath: upload.objectPath,
    });
    return uploadRpcFailure(parsed.values, error);
  }

  revalidateMediaPaths(productId);
  redirect(`${productMediaPath(productId)}?success=${MEDIA_SUCCESS_UPLOADED}`);
}
