import {
  MEDIA_IMAGE_CLEANUP_WARNING,
  MEDIA_IMAGE_UPLOAD_FAILURE_MESSAGE,
  PRODUCT_IMAGES_BUCKET,
} from "@/features/media/constants";
import {
  buildProductImageObjectPath,
  toProductImageStorageObjectPath,
  toStoredProductImagePath,
  type ValidatedProductImageFile,
} from "@/features/media/image";

export type ProductImageStorageClient = {
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

export async function uploadProductImageObject(options: {
  supabase: ProductImageStorageClient;
  productId: string;
  image: ValidatedProductImageFile;
  randomId?: string;
}): Promise<
  | { ok: true; objectPath: string; storedPath: string }
  | { ok: false; message: string }
> {
  const objectPath = buildProductImageObjectPath(
    options.productId,
    options.image.extension,
    options.randomId ? () => options.randomId! : undefined,
  );

  try {
    const { error } = await options.supabase.storage
      .from(PRODUCT_IMAGES_BUCKET)
      .upload(objectPath, options.image.file, {
        contentType: options.image.mimeType,
        upsert: false,
      });

    if (error) {
      return { ok: false, message: MEDIA_IMAGE_UPLOAD_FAILURE_MESSAGE };
    }

    return {
      ok: true,
      objectPath,
      storedPath: toStoredProductImagePath(objectPath),
    };
  } catch {
    return { ok: false, message: MEDIA_IMAGE_UPLOAD_FAILURE_MESSAGE };
  }
}

export async function deleteProductImageObject(options: {
  supabase: ProductImageStorageClient;
  storedOrObjectPath: string;
}): Promise<{ ok: true } | { ok: false; message: string }> {
  const objectPath = toProductImageStorageObjectPath(
    options.storedOrObjectPath,
  );
  if (!objectPath) {
    return { ok: true };
  }

  try {
    const { error } = await options.supabase.storage
      .from(PRODUCT_IMAGES_BUCKET)
      .remove([objectPath]);

    if (error) {
      return { ok: false, message: MEDIA_IMAGE_CLEANUP_WARNING };
    }

    return { ok: true };
  } catch {
    return { ok: false, message: MEDIA_IMAGE_CLEANUP_WARNING };
  }
}
