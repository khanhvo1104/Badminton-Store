"use server";

import { redirect } from "next/navigation";

import {
  readConfirmation,
  requireBrandActionAuth,
} from "@/features/brands/action-utils";
import {
  BRANDS_LIST_PATH,
  BRAND_ACTIVATION_CONFIRM_REQUIRED_MESSAGE,
  BRAND_AUTH_DENIED_MESSAGE,
  BRAND_GENERIC_FAILURE_MESSAGE,
  BRAND_NOT_FOUND_MESSAGE,
  BRAND_SUCCESS_ACTIVATED,
  BRAND_SUCCESS_DEACTIVATED,
} from "@/features/brands/constants";
import { revalidateBrandPaths } from "@/features/brands/revalidate";
import type { BrandActivationState } from "@/features/brands/types";
import { isValidUuid } from "@/features/brands/validation";

export async function setBrandActive(
  _previousState: BrandActivationState,
  formData: FormData,
): Promise<BrandActivationState> {
  const brandId = readString(formData, "id");
  const nextActive = readDesiredActive(formData);
  const currentActive = !nextActive;
  const confirmed =
    readConfirmation(formData, "confirmed") ||
    readConfirmation(formData, "confirm");

  if (!confirmed) {
    return {
      status: "error",
      message: BRAND_ACTIVATION_CONFIRM_REQUIRED_MESSAGE,
      fieldErrors: { confirmed: BRAND_ACTIVATION_CONFIRM_REQUIRED_MESSAGE },
      isActive: currentActive,
    };
  }

  if (!isValidUuid(brandId)) {
    return {
      status: "error",
      message: BRAND_NOT_FOUND_MESSAGE,
      fieldErrors: {},
      isActive: currentActive,
    };
  }

  const auth = await requireBrandActionAuth();
  if (!auth.ok) {
    return {
      status: "error",
      message: BRAND_AUTH_DENIED_MESSAGE,
      fieldErrors: {},
      isActive: currentActive,
    };
  }

  try {
    const { data, error } = await auth.supabase
      .from("brands")
      .select("id, is_active")
      .eq("id", brandId)
      .maybeSingle();

    if (
      error ||
      !isRecord(data) ||
      typeof data.id !== "string" ||
      data.id !== brandId
    ) {
      return {
        status: "error",
        message: BRAND_NOT_FOUND_MESSAGE,
        fieldErrors: {},
        isActive: currentActive,
      };
    }

    const { error: updateError } = await auth.supabase
      .from("brands")
      .update({ is_active: nextActive })
      .eq("id", brandId);

    if (updateError) {
      return {
        status: "error",
        message: BRAND_GENERIC_FAILURE_MESSAGE,
        fieldErrors: {},
        isActive: currentActive,
      };
    }
  } catch {
    return {
      status: "error",
      message: BRAND_GENERIC_FAILURE_MESSAGE,
      fieldErrors: {},
      isActive: currentActive,
    };
  }

  revalidateBrandPaths(brandId);
  redirect(
    `${BRANDS_LIST_PATH}?success=${
      nextActive ? BRAND_SUCCESS_ACTIVATED : BRAND_SUCCESS_DEACTIVATED
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
