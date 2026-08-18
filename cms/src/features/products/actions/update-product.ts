"use server";

import { redirect } from "next/navigation";

import {
  denialState,
  errorState,
  requireProductActionAuth,
} from "@/features/products/action-utils";
import {
  PRODUCT_DETAIL_COLUMNS,
  PRODUCT_GENERIC_FAILURE_MESSAGE,
  PRODUCT_NOT_FOUND_MESSAGE,
  PRODUCT_SUCCESS_UPDATED,
  productEditPath,
} from "@/features/products/constants";
import {
  isSlugUniqueViolation,
  toProductMutationFailureMessage,
} from "@/features/products/errors";
import {
  buildProductMutationPayload,
  parseProductFormInput,
  preserveSafeProductValues,
  readProductFormValues,
} from "@/features/products/form-validation";
import { isProductDetailRow } from "@/features/products/mappers";
import { validateProductReferences } from "@/features/products/references";
import type { ProductReferenceQueryClient } from "@/features/products/references";
import { revalidateProductPaths } from "@/features/products/revalidate";
import type { ProductFormState } from "@/features/products/types";
import { isValidUuid } from "@/features/products/validation";

export async function updateProduct(
  productId: string,
  _previousState: ProductFormState,
  formData: FormData,
): Promise<ProductFormState> {
  const auth = await requireProductActionAuth();
  if (!auth.ok) {
    return denialState(
      preserveSafeProductValues(readProductFormValues(formData)),
    );
  }

  if (!isValidUuid(productId)) {
    return errorState(
      preserveSafeProductValues(readProductFormValues(formData)),
      PRODUCT_NOT_FOUND_MESSAGE,
    );
  }

  let existingPublishedAt: string | null = null;
  let existingCategoryId: string | null = null;
  let existingBrandId: string | null = null;

  try {
    const { data, error } = await auth.supabase
      .from("products")
      .select(PRODUCT_DETAIL_COLUMNS)
      .eq("id", productId)
      .maybeSingle();

    if (error) {
      return errorState(
        preserveSafeProductValues(readProductFormValues(formData)),
        PRODUCT_GENERIC_FAILURE_MESSAGE,
      );
    }
    if (data === null) {
      return errorState(
        preserveSafeProductValues(readProductFormValues(formData)),
        PRODUCT_NOT_FOUND_MESSAGE,
      );
    }
    if (!isProductDetailRow(data)) {
      return errorState(
        preserveSafeProductValues(readProductFormValues(formData)),
        PRODUCT_GENERIC_FAILURE_MESSAGE,
      );
    }

    existingPublishedAt = data.published_at;
    existingCategoryId = data.category_id;
    existingBrandId = data.brand_id;
  } catch {
    return errorState(
      preserveSafeProductValues(readProductFormValues(formData)),
      PRODUCT_GENERIC_FAILURE_MESSAGE,
    );
  }

  const parsed = parseProductFormInput(formData, { existingPublishedAt });
  if (!parsed.ok) {
    return errorState(parsed.values, parsed.message, parsed.fieldErrors);
  }

  const references = await validateProductReferences({
    supabase: auth.supabase as unknown as ProductReferenceQueryClient,
    categoryId: parsed.data.categoryId,
    brandId: parsed.data.brandId,
    status: parsed.data.status,
    existingCategoryId: existingCategoryId ?? undefined,
    existingBrandId: existingBrandId,
  });
  if (!references.ok) {
    return errorState(parsed.values, references.message, {
      [references.field]: references.message,
    });
  }

  const payload = buildProductMutationPayload(parsed.data);

  try {
    const { data, error } = await auth.supabase
      .from("products")
      .update(payload)
      .eq("id", productId)
      .select("id")
      .maybeSingle();

    if (error) {
      const message = toProductMutationFailureMessage(error);
      return errorState(
        parsed.values,
        message,
        isSlugUniqueViolation(error) ? { slug: message } : {},
      );
    }

    if (data === null) {
      return errorState(parsed.values, PRODUCT_NOT_FOUND_MESSAGE);
    }
  } catch {
    return errorState(parsed.values, PRODUCT_GENERIC_FAILURE_MESSAGE);
  }

  revalidateProductPaths(productId);
  redirect(`${productEditPath(productId)}?success=${PRODUCT_SUCCESS_UPDATED}`);
}
