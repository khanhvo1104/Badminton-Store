"use server";

import { redirect } from "next/navigation";

import {
  denialState,
  errorState,
  requireCategoryActionAuth,
  successState,
} from "@/features/categories/action-utils";
import {
  CATEGORY_GENERIC_FAILURE_MESSAGE,
  CATEGORY_IMAGE_CLEANUP_WARNING,
  CATEGORY_LIST_COLUMNS,
  CATEGORY_NOT_FOUND_MESSAGE,
  CATEGORY_SUCCESS_UPDATED,
  categoryEditPath,
} from "@/features/categories/constants";
import {
  isSlugUniqueViolation,
  toCategoryMutationFailureMessage,
} from "@/features/categories/errors";
import { assertSafeCategoryParent } from "@/features/categories/hierarchy";
import { readOptionalCategoryImage } from "@/features/categories/image";
import { isCategoryRow } from "@/features/categories/mappers";
import { revalidateCategoryPaths } from "@/features/categories/revalidate";
import {
  deleteCategoryImageObject,
  uploadCategoryImage,
} from "@/features/categories/storage";
import type { CategoryFormState } from "@/features/categories/types";
import {
  isValidUuid,
  parseCategoryFormInput,
} from "@/features/categories/validation";

export async function updateCategory(
  _previousState: CategoryFormState,
  formData: FormData,
): Promise<CategoryFormState> {
  const auth = await requireCategoryActionAuth();
  if (!auth.ok) {
    return denialState(parseCategoryFormInput(formData).values);
  }

  const categoryIdRaw = formData.get("id");
  const categoryId =
    typeof categoryIdRaw === "string" ? categoryIdRaw.trim() : "";

  if (!isValidUuid(categoryId)) {
    return errorState(
      parseCategoryFormInput(formData).values,
      CATEGORY_NOT_FOUND_MESSAGE,
    );
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

  let existingImagePath: string | null = null;
  try {
    const { data, error } = await auth.supabase
      .from("categories")
      .select(CATEGORY_LIST_COLUMNS)
      .eq("id", categoryId)
      .maybeSingle();

    if (error) {
      return errorState(parsed.values, CATEGORY_GENERIC_FAILURE_MESSAGE);
    }
    if (data === null) {
      return errorState(parsed.values, CATEGORY_NOT_FOUND_MESSAGE);
    }
    if (!isCategoryRow(data)) {
      return errorState(parsed.values, CATEGORY_GENERIC_FAILURE_MESSAGE);
    }
    existingImagePath = data.image_path;
  } catch {
    return errorState(parsed.values, CATEGORY_GENERIC_FAILURE_MESSAGE);
  }

  const parentCheck = await assertSafeCategoryParent(auth.supabase, {
    categoryId,
    parentId: parsed.data.parentId,
  });
  if (!parentCheck.ok) {
    return errorState(parsed.values, parentCheck.message, {
      parentId: parentCheck.message,
    });
  }

  let uploadedStoredPath: string | null = null;
  let uploadedObjectPath: string | null = null;
  let cleanupWarning: string | null = null;

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
    uploadedStoredPath = upload.storedPath;
    uploadedObjectPath = upload.objectPath;
  }

  const nextImagePath = uploadedStoredPath ?? existingImagePath;

  try {
    const { error } = await auth.supabase
      .from("categories")
      .update({
        name: parsed.data.name,
        slug: parsed.data.slug,
        description: parsed.data.description,
        parent_id: parsed.data.parentId,
        sort_order: parsed.data.sortOrder,
        is_active: parsed.data.isActive,
        image_path: nextImagePath,
      })
      .eq("id", categoryId);

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

  if (
    uploadedStoredPath &&
    existingImagePath &&
    existingImagePath !== uploadedStoredPath
  ) {
    const cleanup = await deleteCategoryImageObject({
      supabase: auth.supabase,
      storedOrObjectPath: existingImagePath,
    });
    if (!cleanup.ok) {
      cleanupWarning = CATEGORY_IMAGE_CLEANUP_WARNING;
    }
  }

  revalidateCategoryPaths(categoryId);

  if (cleanupWarning) {
    return successState(parsed.values, cleanupWarning);
  }

  redirect(
    `${categoryEditPath(categoryId)}?success=${CATEGORY_SUCCESS_UPDATED}`,
  );
}
