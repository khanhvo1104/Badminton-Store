import {
  CATEGORY_ASSETS_BUCKET,
  CATEGORY_IMAGE_CLEANUP_WARNING,
  CATEGORY_IMAGE_UPLOAD_FAILURE_MESSAGE,
} from "@/features/categories/constants";
import {
  buildCategoryObjectPath,
  toStorageObjectPath,
  toStoredImagePath,
  type ValidatedCategoryImage,
} from "@/features/categories/image";

export type CategoryStorageClient = {
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

export async function uploadCategoryImage(options: {
  supabase: CategoryStorageClient;
  categoryId: string;
  image: ValidatedCategoryImage;
  randomId?: string;
}): Promise<
  | { ok: true; objectPath: string; storedPath: string }
  | { ok: false; message: string }
> {
  const objectPath = buildCategoryObjectPath(
    options.categoryId,
    options.image.extension,
    options.randomId ? () => options.randomId! : undefined,
  );

  try {
    const { error } = await options.supabase.storage
      .from(CATEGORY_ASSETS_BUCKET)
      .upload(objectPath, options.image.file, {
        contentType: options.image.mimeType,
        upsert: false,
      });

    if (error) {
      return { ok: false, message: CATEGORY_IMAGE_UPLOAD_FAILURE_MESSAGE };
    }

    return {
      ok: true,
      objectPath,
      storedPath: toStoredImagePath(objectPath),
    };
  } catch {
    return { ok: false, message: CATEGORY_IMAGE_UPLOAD_FAILURE_MESSAGE };
  }
}

export async function deleteCategoryImageObject(options: {
  supabase: CategoryStorageClient;
  storedOrObjectPath: string;
}): Promise<{ ok: true } | { ok: false; message: string }> {
  const objectPath = toStorageObjectPath(options.storedOrObjectPath);
  if (!objectPath) {
    return { ok: true };
  }

  try {
    const { error } = await options.supabase.storage
      .from(CATEGORY_ASSETS_BUCKET)
      .remove([objectPath]);

    if (error) {
      return { ok: false, message: CATEGORY_IMAGE_CLEANUP_WARNING };
    }

    return { ok: true };
  } catch {
    return { ok: false, message: CATEGORY_IMAGE_CLEANUP_WARNING };
  }
}
