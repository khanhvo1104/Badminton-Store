"use server";

import { redirect } from "next/navigation";

import {
  readConfirmation,
  requireCategoryActionAuth,
} from "@/features/categories/action-utils";
import {
  CATEGORIES_LIST_PATH,
  CATEGORY_ACTIVATION_CONFIRM_REQUIRED_MESSAGE,
  CATEGORY_AUTH_DENIED_MESSAGE,
  CATEGORY_GENERIC_FAILURE_MESSAGE,
  CATEGORY_NOT_FOUND_MESSAGE,
  CATEGORY_SUCCESS_ACTIVATED,
  CATEGORY_SUCCESS_DEACTIVATED,
} from "@/features/categories/constants";
import { revalidateCategoryPaths } from "@/features/categories/revalidate";
import type { CategoryActivationState } from "@/features/categories/types";
import { isValidUuid } from "@/features/categories/validation";

export async function setCategoryActive(
  _previousState: CategoryActivationState,
  formData: FormData,
): Promise<CategoryActivationState> {
  const categoryId = readString(formData, "id");
  const nextActive = readDesiredActive(formData);
  const currentActive = !nextActive;
  const confirmed =
    readConfirmation(formData, "confirmed") ||
    readConfirmation(formData, "confirm");

  if (!confirmed) {
    return {
      status: "error",
      message: CATEGORY_ACTIVATION_CONFIRM_REQUIRED_MESSAGE,
      fieldErrors: { confirmed: CATEGORY_ACTIVATION_CONFIRM_REQUIRED_MESSAGE },
      isActive: currentActive,
    };
  }

  if (!isValidUuid(categoryId)) {
    return {
      status: "error",
      message: CATEGORY_NOT_FOUND_MESSAGE,
      fieldErrors: {},
      isActive: currentActive,
    };
  }

  const auth = await requireCategoryActionAuth();
  if (!auth.ok) {
    return {
      status: "error",
      message: CATEGORY_AUTH_DENIED_MESSAGE,
      fieldErrors: {},
      isActive: currentActive,
    };
  }

  try {
    const { data, error } = await auth.supabase
      .from("categories")
      .select("id, is_active")
      .eq("id", categoryId)
      .maybeSingle();

    if (
      error ||
      !isRecord(data) ||
      typeof data.id !== "string" ||
      data.id !== categoryId
    ) {
      return {
        status: "error",
        message: CATEGORY_NOT_FOUND_MESSAGE,
        fieldErrors: {},
        isActive: currentActive,
      };
    }

    const { error: updateError } = await auth.supabase
      .from("categories")
      .update({ is_active: nextActive })
      .eq("id", categoryId);

    if (updateError) {
      return {
        status: "error",
        message: CATEGORY_GENERIC_FAILURE_MESSAGE,
        fieldErrors: {},
        isActive: currentActive,
      };
    }
  } catch {
    return {
      status: "error",
      message: CATEGORY_GENERIC_FAILURE_MESSAGE,
      fieldErrors: {},
      isActive: currentActive,
    };
  }

  revalidateCategoryPaths(categoryId);
  redirect(
    `${CATEGORIES_LIST_PATH}?success=${
      nextActive ? CATEGORY_SUCCESS_ACTIVATED : CATEGORY_SUCCESS_DEACTIVATED
    }`,
  );
}

function readString(formData: FormData, key: string): string {
  const value = formData.get(key);
  return typeof value === "string" ? value.trim() : "";
}

function readDesiredActive(formData: FormData): boolean {
  const value = formData.get("is_active");
  if (typeof value !== "string") {
    return false;
  }
  return ["on", "true", "1", "yes"].includes(value.trim().toLowerCase());
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null;
}
