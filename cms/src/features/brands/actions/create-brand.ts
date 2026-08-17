"use server";

import { redirect } from "next/navigation";

import {
  denialState,
  errorState,
  requireBrandActionAuth,
} from "@/features/brands/action-utils";
import {
  BRAND_GENERIC_FAILURE_MESSAGE,
  BRAND_SUCCESS_CREATED,
  brandEditPath,
} from "@/features/brands/constants";
import {
  isSlugUniqueViolation,
  toBrandMutationFailureMessage,
} from "@/features/brands/errors";
import { readOptionalBrandLogo } from "@/features/brands/logo";
import { revalidateBrandPaths } from "@/features/brands/revalidate";
import {
  deleteBrandLogoObject,
  uploadBrandLogo,
} from "@/features/brands/storage";
import type { BrandFormState } from "@/features/brands/types";
import { parseBrandFormInput } from "@/features/brands/validation";

export async function createBrand(
  _previousState: BrandFormState,
  formData: FormData,
): Promise<BrandFormState> {
  const auth = await requireBrandActionAuth();
  if (!auth.ok) {
    return denialState(parseBrandFormInput(formData).values);
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

  const brandId = crypto.randomUUID();
  let uploadedObjectPath: string | null = null;
  let uploadedStoredPath: string | null = null;

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
    uploadedObjectPath = upload.objectPath;
    uploadedStoredPath = upload.storedPath;
  }

  try {
    const { error } = await auth.supabase.from("brands").insert({
      id: brandId,
      name: parsed.data.name,
      slug: parsed.data.slug,
      description: parsed.data.description,
      website_url: parsed.data.websiteUrl,
      country_of_origin: parsed.data.countryOfOrigin,
      sort_order: parsed.data.sortOrder,
      is_active: parsed.data.isActive,
      logo_path: uploadedStoredPath,
    });

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

  revalidateBrandPaths(brandId);
  redirect(`${brandEditPath(brandId)}?success=${BRAND_SUCCESS_CREATED}`);
}
