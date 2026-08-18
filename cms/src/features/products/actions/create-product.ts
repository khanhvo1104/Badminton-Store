"use server";

import { redirect } from "next/navigation";

import {
  denialState,
  errorState,
  requireProductActionAuth,
} from "@/features/products/action-utils";
import {
  PRODUCT_GENERIC_FAILURE_MESSAGE,
  PRODUCT_SUCCESS_CREATED,
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
import { validateProductReferences } from "@/features/products/references";
import type { ProductReferenceQueryClient } from "@/features/products/references";
import { revalidateProductPaths } from "@/features/products/revalidate";
import type { ProductFormState } from "@/features/products/types";

export async function createProduct(
  _previousState: ProductFormState,
  formData: FormData,
): Promise<ProductFormState> {
  const auth = await requireProductActionAuth();
  if (!auth.ok) {
    return denialState(
      preserveSafeProductValues(readProductFormValues(formData)),
    );
  }

  const parsed = parseProductFormInput(formData);
  if (!parsed.ok) {
    return errorState(parsed.values, parsed.message, parsed.fieldErrors);
  }

  const references = await validateProductReferences({
    supabase: auth.supabase as unknown as ProductReferenceQueryClient,
    categoryId: parsed.data.categoryId,
    brandId: parsed.data.brandId,
    status: parsed.data.status,
  });
  if (!references.ok) {
    return errorState(parsed.values, references.message, {
      [references.field]: references.message,
    });
  }

  const productId = crypto.randomUUID();
  const payload = buildProductMutationPayload(parsed.data);

  try {
    const { error } = await auth.supabase.from("products").insert({
      id: productId,
      ...payload,
    });

    if (error) {
      const message = toProductMutationFailureMessage(error);
      return errorState(
        parsed.values,
        message,
        isSlugUniqueViolation(error) ? { slug: message } : {},
      );
    }
  } catch {
    return errorState(parsed.values, PRODUCT_GENERIC_FAILURE_MESSAGE);
  }

  revalidateProductPaths(productId);
  redirect(`${productEditPath(productId)}?success=${PRODUCT_SUCCESS_CREATED}`);
}
