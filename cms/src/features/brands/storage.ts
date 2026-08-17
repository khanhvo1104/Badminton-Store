import {
  BRAND_ASSETS_BUCKET,
  BRAND_LOGO_CLEANUP_WARNING,
  BRAND_LOGO_UPLOAD_FAILURE_MESSAGE,
} from "@/features/brands/constants";
import {
  buildBrandObjectPath,
  toStorageObjectPath,
  toStoredLogoPath,
  type ValidatedBrandLogo,
} from "@/features/brands/logo";

export type BrandStorageClient = {
  storage: {
    from: (bucket: string) => {
      upload: (
        path: string,
        file: File | Blob | ArrayBuffer | Uint8Array,
        options: { contentType: string; upsert: boolean },
      ) => PromiseLike<{ data: unknown; error: unknown }>;
      remove: (
        paths: string[],
      ) => PromiseLike<{ data: unknown; error: unknown }>;
    };
  };
};

export async function uploadBrandLogo(options: {
  supabase: BrandStorageClient;
  brandId: string;
  logo: ValidatedBrandLogo;
  randomId?: string;
}): Promise<
  | { ok: true; objectPath: string; storedPath: string }
  | { ok: false; message: string }
> {
  const objectPath = buildBrandObjectPath(
    options.brandId,
    options.logo.extension,
    options.randomId ? () => options.randomId! : undefined,
  );

  try {
    const { error } = await options.supabase.storage
      .from(BRAND_ASSETS_BUCKET)
      .upload(objectPath, options.logo.file, {
        contentType: options.logo.mimeType,
        upsert: false,
      });

    if (error) {
      return { ok: false, message: BRAND_LOGO_UPLOAD_FAILURE_MESSAGE };
    }

    return {
      ok: true,
      objectPath,
      storedPath: toStoredLogoPath(objectPath),
    };
  } catch {
    return { ok: false, message: BRAND_LOGO_UPLOAD_FAILURE_MESSAGE };
  }
}

export async function deleteBrandLogoObject(options: {
  supabase: BrandStorageClient;
  storedOrObjectPath: string;
}): Promise<{ ok: true } | { ok: false; message: string }> {
  const objectPath = toStorageObjectPath(options.storedOrObjectPath);
  if (!objectPath) {
    return { ok: true };
  }

  try {
    const { error } = await options.supabase.storage
      .from(BRAND_ASSETS_BUCKET)
      .remove([objectPath]);

    if (error) {
      return { ok: false, message: BRAND_LOGO_CLEANUP_WARNING };
    }

    return { ok: true };
  } catch {
    return { ok: false, message: BRAND_LOGO_CLEANUP_WARNING };
  }
}
