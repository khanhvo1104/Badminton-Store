"use server";

import { redirect } from "next/navigation";

import {
  denialState,
  errorState,
  requireCategoryActionAuth,
} from "@/features/categories/action-utils";
import {
  CATEGORY_GENERIC_FAILURE_MESSAGE,
  CATEGORY_SUCCESS_CREATED,
  categoryEditPath,
} from "@/features/categories/constants";
import {
  isSlugUniqueViolation,
  toCategoryMutationFailureMessage,
} from "@/features/categories/errors";
import { assertSafeCategoryParent } from "@/features/categories/hierarchy";
import { readOptionalCategoryImage } from "@/features/categories/image";
import { revalidateCategoryPaths } from "@/features/categories/revalidate";
import {
  deleteCategoryImageObject,
  uploadCategoryImage,
} from "@/features/categories/storage";
import type { CategoryFormState } from "@/features/categories/types";
import { parseCategoryFormInput } from "@/features/categories/validation";

export async function createCategory(
  _previousState: CategoryFormState,
  formData: FormData,
): Promise<CategoryFormState> {
  const auth = await requireCategoryActionAuth();
  if (!auth.ok) {
    return denialState(parseCategoryFormInput(formData).values);
  }

  const parsed = parseCategoryFormInput(formData);
  if (!parsed.ok) {
    return errorState(parsed.values, parsed.message, parsed.fieldErrors);
  }

  const imageValidation = readOptionalCategoryImage(formData);
  if (!imageValidation.ok) {
    return errorState(parsed.values, imageValidation.message, {
      image: imageValidation.message,
    });
  }

  const parentCheck = await assertSafeCategoryParent(auth.supabase, {
    parentId: parsed.data.parentId,
  });
  if (!parentCheck.ok) {
    return errorState(parsed.values, parentCheck.message, {
      parentId: parentCheck.message,
    });
  }

  const categoryId = crypto.randomUUID();
  let uploadedObjectPath: string | null = null;
  let uploadedStoredPath: string | null = null;

  if (imageValidation.image) {
    const upload = await uploadCategoryImage({
      supabase: auth.supabase,
      categoryId,
      image: imageValidation.image,
    });
    if (!upload.ok) {
      return errorState(parsed.values, upload.message, {
        image: upload.message,
      });
    }
    uploadedObjectPath = upload.objectPath;
    uploadedStoredPath = upload.storedPath;
  }

  try {
    const { error } = await auth.supabase.from("categories").insert({
      id: categoryId,
      name: parsed.data.name,
      slug: parsed.data.slug,
      description: parsed.data.description,
      parent_id: parsed.data.parentId,
      sort_order: parsed.data.sortOrder,
      is_active: parsed.data.isActive,
      image_path: uploadedStoredPath,
    });

    if (error) {
      if (uploadedObjectPath) {
        await deleteCategoryImageObject({
          supabase: auth.supabase,
          storedOrObjectPath: uploadedObjectPath,
        });
      }
      const message = toCategoryMutationFailureMessage(error);
      return errorState(
        parsed.values,
        message,
        isSlugUniqueViolation(error) ? { slug: message } : {},
      );
    }
  } catch {
    if (uploadedObjectPath) {
      await deleteCategoryImageObject({
        supabase: auth.supabase,
        storedOrObjectPath: uploadedObjectPath,
      });
    }
    return errorState(parsed.values, CATEGORY_GENERIC_FAILURE_MESSAGE);
  }

  revalidateCategoryPaths(categoryId);
  redirect(
    `${categoryEditPath(categoryId)}?success=${CATEGORY_SUCCESS_CREATED}`,
  );
}
