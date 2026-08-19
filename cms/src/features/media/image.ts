import {
  MEDIA_IMAGE_INVALID_MESSAGE,
  MEDIA_IMAGE_REQUIRED_MESSAGE,
  PRODUCT_IMAGE_EXTENSION_BY_MIME,
  PRODUCT_IMAGE_MAX_BYTES,
  PRODUCT_IMAGE_MIME_TYPES,
  PRODUCT_IMAGES_BUCKET,
  type ProductImageMimeType,
} from "@/features/media/constants";

export type ValidatedProductImageFile = {
  file: File;
  mimeType: ProductImageMimeType;
  extension: string;
};

export type ProductImageFileValidationResult =
  | { ok: true; image: ValidatedProductImageFile }
  | { ok: true; image: null }
  | { ok: false; message: string };

export function readOptionalProductImageFile(
  formData: FormData,
  key = "image",
): ProductImageFileValidationResult {
  const value = formData.get(key);
  if (value === null || value === "") {
    return { ok: true, image: null };
  }
  if (!(value instanceof File)) {
    return { ok: false, message: MEDIA_IMAGE_INVALID_MESSAGE };
  }
  return validateProductImageFile(value);
}

export function readRequiredProductImageFile(
  formData: FormData,
  key = "image",
):
  | { ok: true; image: ValidatedProductImageFile }
  | { ok: false; message: string } {
  const result = readOptionalProductImageFile(formData, key);
  if (!result.ok) {
    return result;
  }
  if (!result.image) {
    return {
      ok: false,
      message: MEDIA_IMAGE_REQUIRED_MESSAGE,
    };
  }
  return { ok: true, image: result.image };
}

export function validateProductImageFile(
  file: File | null | undefined,
): ProductImageFileValidationResult {
  if (!file) {
    return { ok: true, image: null };
  }

  if (file.size === 0 && (!file.name || file.name === "")) {
    return { ok: true, image: null };
  }

  const fileName = file.name.trim().toLowerCase();
  if (
    fileName.endsWith(".svg") ||
    file.type.trim().toLowerCase() === "image/svg+xml"
  ) {
    return { ok: false, message: MEDIA_IMAGE_INVALID_MESSAGE };
  }

  if (file.size <= 0 || file.size > PRODUCT_IMAGE_MAX_BYTES) {
    return { ok: false, message: MEDIA_IMAGE_INVALID_MESSAGE };
  }

  const mimeType = file.type.trim().toLowerCase();
  if (!isAllowedMimeType(mimeType)) {
    return { ok: false, message: MEDIA_IMAGE_INVALID_MESSAGE };
  }

  return {
    ok: true,
    image: {
      file,
      mimeType,
      extension: PRODUCT_IMAGE_EXTENSION_BY_MIME[mimeType],
    },
  };
}

export function buildProductImageObjectPath(
  productId: string,
  extension: string,
  idFactory: () => string = () => crypto.randomUUID(),
): string {
  const raw = extension.startsWith(".") ? extension.slice(1) : extension;
  const safeExtension = raw.replace(/[^a-z0-9]/gi, "").toLowerCase() || "bin";
  return `${productId}/${idFactory()}.${safeExtension}`;
}

export function toStoredProductImagePath(objectPath: string): string {
  const normalized = objectPath.replace(/^\/+/, "");
  if (normalized.startsWith(`${PRODUCT_IMAGES_BUCKET}/`)) {
    return normalized;
  }
  return `${PRODUCT_IMAGES_BUCKET}/${normalized}`;
}

export function toProductImageStorageObjectPath(storedPath: string): string {
  const normalized = storedPath.replace(/^\/+/, "");
  const prefix = `${PRODUCT_IMAGES_BUCKET}/`;
  if (normalized.startsWith(prefix)) {
    return normalized.slice(prefix.length);
  }
  return normalized;
}

export function isSafeProductImagePreviewPath(
  productId: string,
  storedPath: string | null | undefined,
): boolean {
  if (!storedPath || !storedPath.trim()) {
    return false;
  }

  const objectPath = toProductImageStorageObjectPath(storedPath);
  if (
    !objectPath ||
    objectPath.includes("..") ||
    objectPath.includes("\\") ||
    objectPath.startsWith("/") ||
    objectPath.includes("//")
  ) {
    return false;
  }

  const lower = objectPath.toLowerCase();
  if (lower.endsWith(".svg") || lower.includes(".svg?")) {
    return false;
  }

  const prefix = `${productId}/`;
  if (!objectPath.startsWith(prefix)) {
    return false;
  }

  const rest = objectPath.slice(prefix.length);
  return rest.length > 0 && !rest.includes("/");
}

export function buildProductImagePublicUrl(
  supabaseUrl: string,
  productId: string,
  storedPath: string | null | undefined,
): string | null {
  if (!storedPath || !storedPath.trim() || !supabaseUrl.trim()) {
    return null;
  }
  if (!isSafeProductImagePreviewPath(productId, storedPath)) {
    return null;
  }

  const objectPath = toProductImageStorageObjectPath(storedPath);
  const base = supabaseUrl.replace(/\/+$/, "");
  return `${base}/storage/v1/object/public/${PRODUCT_IMAGES_BUCKET}/${objectPath}`;
}

function isAllowedMimeType(value: string): value is ProductImageMimeType {
  return (PRODUCT_IMAGE_MIME_TYPES as readonly string[]).includes(value);
}
