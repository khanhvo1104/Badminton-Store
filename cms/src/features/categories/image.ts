import {
  CATEGORY_ASSETS_BUCKET,
  CATEGORY_IMAGE_EXTENSION_BY_MIME,
  CATEGORY_IMAGE_INVALID_MESSAGE,
  CATEGORY_IMAGE_MAX_BYTES,
  CATEGORY_IMAGE_MIME_TYPES,
  type CategoryImageMimeType,
} from "@/features/categories/constants";

export type ValidatedCategoryImage = {
  file: File;
  mimeType: CategoryImageMimeType;
  extension: string;
};

export type CategoryImageValidationResult =
  | { ok: true; image: ValidatedCategoryImage }
  | { ok: true; image: null }
  | { ok: false; message: string };

export function readOptionalCategoryImage(
  formData: FormData,
  key = "image",
): CategoryImageValidationResult {
  const value = formData.get(key);

  if (value === null || value === "") {
    return { ok: true, image: null };
  }

  if (!(value instanceof File)) {
    return { ok: false, message: CATEGORY_IMAGE_INVALID_MESSAGE };
  }

  return validateCategoryImageFile(value);
}

export function validateCategoryImageFile(
  file: File | null | undefined,
): CategoryImageValidationResult {
  if (!file) {
    return { ok: true, image: null };
  }

  if (file.size === 0) {
    return { ok: true, image: null };
  }

  if (file.size > CATEGORY_IMAGE_MAX_BYTES) {
    return { ok: false, message: CATEGORY_IMAGE_INVALID_MESSAGE };
  }

  const mimeType = file.type.trim().toLowerCase();
  if (!isAllowedMimeType(mimeType)) {
    return { ok: false, message: CATEGORY_IMAGE_INVALID_MESSAGE };
  }

  return {
    ok: true,
    image: {
      file,
      mimeType,
      extension: CATEGORY_IMAGE_EXTENSION_BY_MIME[mimeType],
    },
  };
}

export const validateCategoryImageMeta = validateCategoryImageFile;

export function buildCategoryObjectPath(
  categoryId: string,
  extension: string,
  idFactory: () => string = () => crypto.randomUUID(),
): string {
  const raw = extension.startsWith(".") ? extension.slice(1) : extension;
  const safeExtension = raw.replace(/[^a-z0-9]/gi, "").toLowerCase() || "bin";
  return `${categoryId}/${idFactory()}.${safeExtension}`;
}

export const generateCategoryObjectPath = buildCategoryObjectPath;

export function toStoredImagePath(objectPath: string): string {
  const normalized = objectPath.replace(/^\/+/, "");
  if (normalized.startsWith(`${CATEGORY_ASSETS_BUCKET}/`)) {
    return normalized;
  }
  return `${CATEGORY_ASSETS_BUCKET}/${normalized}`;
}

export const toStoredCategoryImagePath = toStoredImagePath;

export function toStorageObjectPath(storedPath: string): string {
  const normalized = storedPath.replace(/^\/+/, "");
  const prefix = `${CATEGORY_ASSETS_BUCKET}/`;
  if (normalized.startsWith(prefix)) {
    return normalized.slice(prefix.length);
  }
  return normalized;
}

export const toCategoryStorageObjectPath = toStorageObjectPath;

export function buildCategoryImagePublicUrl(
  first: string | null | undefined,
  second?: string | null | undefined,
): string | null {
  let supabaseUrl: string;
  let storedPath: string | null | undefined;

  if (
    typeof first === "string" &&
    (first.startsWith("http://") || first.startsWith("https://"))
  ) {
    supabaseUrl = first;
    storedPath = second;
  } else {
    storedPath = first;
    supabaseUrl = typeof second === "string" ? second : "";
  }

  if (!storedPath || !storedPath.trim() || !supabaseUrl.trim()) {
    return null;
  }

  const objectPath = toStorageObjectPath(storedPath);
  if (!objectPath || objectPath.includes("..") || objectPath.startsWith("/")) {
    return null;
  }

  const base = supabaseUrl.replace(/\/+$/, "");
  return `${base}/storage/v1/object/public/${CATEGORY_ASSETS_BUCKET}/${objectPath}`;
}

function isAllowedMimeType(value: string): value is CategoryImageMimeType {
  return (CATEGORY_IMAGE_MIME_TYPES as readonly string[]).includes(value);
}
