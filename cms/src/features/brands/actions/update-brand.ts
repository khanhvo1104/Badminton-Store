"use server";

import { redirect } from "next/navigation";

import {
  denialState,
  errorState,
  requireBrandActionAuth,
  successState,
} from "@/features/brands/action-utils";
import {
  BRAND_GENERIC_FAILURE_MESSAGE,
  BRAND_LIST_COLUMNS,
  BRAND_LOGO_CLEANUP_WARNING,
  BRAND_NOT_FOUND_MESSAGE,
  BRAND_SUCCESS_UPDATED,
  brandEditPath,
} from "@/features/brands/constants";
import {
  isSlugUniqueViolation,
  toBrandMutationFailureMessage,
} from "@/features/brands/errors";
import { readOptionalBrandLogo } from "@/features/brands/logo";
import { isBrandRow } from "@/features/brands/mappers";
import { revalidateBrandPaths } from "@/features/brands/revalidate";
import {
  deleteBrandLogoObject,
  uploadBrandLogo,
} from "@/features/brands/storage";
import type { BrandFormState } from "@/features/brands/types";
import { isValidUuid, parseBrandFormInput } from "@/features/brands/validation";

export async function updateBrand(
  _previousState: BrandFormState,
  formData: FormData,
): Promise<BrandFormState> {
  const auth = await requireBrandActionAuth();
  if (!auth.ok) {
    return denialState(parseBrandFormInput(formData).values);
  }

  const brandIdRaw = formData.get("id");
  const brandId = typeof brandIdRaw === "string" ? brandIdRaw.trim() : "";

  if (!isValidUuid(brandId)) {
    return errorState(
      parseBrandFormInput(formData).values,
      BRAND_NOT_FOUND_MESSAGE,
    );
  }

  const parsed = parseBrandFormInput(formData);
  if (!parsed.ok) {
    return errorState(parsed.values, parsed.message, parsed.fieldErrors);
  }

  const logoValidation = readOptionalBrandLogo(formData);
  if (!logoValidation.ok) {
    return errorState(parsed.values, logoValidation.message, {
      logo: logoValidation.message,
    });
  }

  let existingLogoPath: string | null = null;
  try {
    const { data, error } = await auth.supabase
      .from("brands")
      .select(BRAND_LIST_COLUMNS)
      .eq("id", brandId)
      .maybeSingle();

    if (error) {
      return errorState(parsed.values, BRAND_GENERIC_FAILURE_MESSAGE);
    }
    if (data === null) {
      return errorState(parsed.values, BRAND_NOT_FOUND_MESSAGE);
    }
    if (!isBrandRow(data)) {
      return errorState(parsed.values, BRAND_GENERIC_FAILURE_MESSAGE);
    }
    existingLogoPath = data.logo_path;
  } catch {
    return errorState(parsed.values, BRAND_GENERIC_FAILURE_MESSAGE);
  }

  let uploadedStoredPath: string | null = null;
  let uploadedObjectPath: string | null = null;
  let cleanupWarning: string | null = null;

  if (logoValidation.logo) {
    const upload = await uploadBrandLogo({
      supabase: auth.supabase,
      brandId,
      logo: logoValidation.logo,
    });
    if (!upload.ok) {
      return errorState(parsed.values, upload.message, {
        logo: upload.message,
      });
    }
    uploadedStoredPath = upload.storedPath;
    uploadedObjectPath = upload.objectPath;
  }

  const nextLogoPath = uploadedStoredPath ?? existingLogoPath;

  try {
    const { error } = await auth.supabase
      .from("brands")
      .update({
        name: parsed.data.name,
        slug: parsed.data.slug,
        description: parsed.data.description,
        website_url: parsed.data.websiteUrl,
        country_of_origin: parsed.data.countryOfOrigin,
        sort_order: parsed.data.sortOrder,
        is_active: parsed.data.isActive,
        logo_path: nextLogoPath,
      })
      .eq("id", brandId);

    if (error) {
      if (uploadedObjectPath) {
        await deleteBrandLogoObject({
          supabase: auth.supabase,
          storedOrObjectPath: uploadedObjectPath,
        });
      }
      const message = toBrandMutationFailureMessage(error);
      return errorState(
        parsed.values,
        message,
        isSlugUniqueViolation(error) ? { slug: message } : {},
      );
    }
  } catch {
    if (uploadedObjectPath) {
      await deleteBrandLogoObject({
        supabase: auth.supabase,
        storedOrObjectPath: uploadedObjectPath,
      });
    }
    return errorState(parsed.values, BRAND_GENERIC_FAILURE_MESSAGE);
  }

  if (
    uploadedStoredPath &&
    existingLogoPath &&
    existingLogoPath !== uploadedStoredPath
  ) {
    const cleanup = await deleteBrandLogoObject({
      supabase: auth.supabase,
      storedOrObjectPath: existingLogoPath,
    });
    if (!cleanup.ok) {
      cleanupWarning = BRAND_LOGO_CLEANUP_WARNING;
    }
  }

  revalidateBrandPaths(brandId);

  if (cleanupWarning) {
    return successState(parsed.values, cleanupWarning);
  }

  redirect(`${brandEditPath(brandId)}?success=${BRAND_SUCCESS_UPDATED}`);
}
