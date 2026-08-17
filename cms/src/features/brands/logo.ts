import {
  BRAND_ASSETS_BUCKET,
  BRAND_LOGO_EXTENSION_BY_MIME,
  BRAND_LOGO_INVALID_MESSAGE,
  BRAND_LOGO_MAX_BYTES,
  BRAND_LOGO_MIME_TYPES,
  type BrandLogoMimeType,
} from "@/features/brands/constants";

export type ValidatedBrandLogo = {
  file: File;
  mimeType: BrandLogoMimeType;
  extension: string;
};

export type BrandLogoValidationResult =
  | { ok: true; logo: ValidatedBrandLogo }
  | { ok: true; logo: null }
  | { ok: false; message: string };

export function readOptionalBrandLogo(
  formData: FormData,
  key = "logo",
): BrandLogoValidationResult {
  const value = formData.get(key);

  if (value === null || value === "") {
    return { ok: true, logo: null };
  }

  if (!(value instanceof File)) {
    return { ok: false, message: BRAND_LOGO_INVALID_MESSAGE };
  }

  return validateBrandLogoFile(value);
}

export function validateBrandLogoFile(
  file: File | null | undefined,
): BrandLogoValidationResult {
  if (!file) {
    return { ok: true, logo: null };
  }

  if (file.size === 0 && (!file.name || file.name === "")) {
    return { ok: true, logo: null };
  }

  if (file.size <= 0 || file.size > BRAND_LOGO_MAX_BYTES) {
    return { ok: false, message: BRAND_LOGO_INVALID_MESSAGE };
  }

  const mimeType = file.type.trim().toLowerCase();
  if (!isAllowedMimeType(mimeType)) {
    return { ok: false, message: BRAND_LOGO_INVALID_MESSAGE };
  }

  return {
    ok: true,
    logo: {
      file,
      mimeType,
      extension: BRAND_LOGO_EXTENSION_BY_MIME[mimeType],
    },
  };
}

export const validateBrandLogoMeta = validateBrandLogoFile;

export function buildBrandObjectPath(
  brandId: string,
  extension: string,
  idFactory: () => string = () => crypto.randomUUID(),
): string {
  const raw = extension.startsWith(".") ? extension.slice(1) : extension;
  const safeExtension = raw.replace(/[^a-z0-9]/gi, "").toLowerCase() || "bin";
  return `${brandId}/${idFactory()}.${safeExtension}`;
}

export const generateBrandObjectPath = buildBrandObjectPath;

export function toStoredLogoPath(objectPath: string): string {
  const normalized = objectPath.replace(/^\/+/, "");
  if (normalized.startsWith(`${BRAND_ASSETS_BUCKET}/`)) {
    return normalized;
  }
  return `${BRAND_ASSETS_BUCKET}/${normalized}`;
}

export const toStoredBrandLogoPath = toStoredLogoPath;

export function toStorageObjectPath(storedPath: string): string {
  const normalized = storedPath.replace(/^\/+/, "");
  const prefix = `${BRAND_ASSETS_BUCKET}/`;
  if (normalized.startsWith(prefix)) {
    return normalized.slice(prefix.length);
  }
  return normalized;
}

export const toBrandStorageObjectPath = toStorageObjectPath;

export function buildBrandLogoPublicUrl(
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
  return `${base}/storage/v1/object/public/${BRAND_ASSETS_BUCKET}/${objectPath}`;
}

function isAllowedMimeType(value: string): value is BrandLogoMimeType {
  return (BRAND_LOGO_MIME_TYPES as readonly string[]).includes(value);
}
