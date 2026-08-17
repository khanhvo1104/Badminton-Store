export const BRANDS_LIST_PATH = "/dashboard/brands";
export const BRANDS_ROUTE = BRANDS_LIST_PATH;
export const BRANDS_NEW_PATH = "/dashboard/brands/new";

export function brandEditPath(brandId: string): string {
  return `${BRANDS_LIST_PATH}/${brandId}/edit`;
}

export const BRAND_LIST_COLUMNS =
  "id, name, slug, description, logo_path, website_url, country_of_origin, sort_order, is_active" as const;

export const BRAND_DETAIL_COLUMNS = BRAND_LIST_COLUMNS;

export const BRAND_ASSETS_BUCKET = "brand-assets";

export const BRAND_NAME_MAX_LENGTH = 120;
export const BRAND_SLUG_MAX_LENGTH = 120;
export const BRAND_DESCRIPTION_MAX_LENGTH = 2000;
export const BRAND_WEBSITE_URL_MAX_LENGTH = 2048;
export const BRAND_COUNTRY_MAX_LENGTH = 80;
export const BRAND_SORT_ORDER_MIN = -1_000_000;
export const BRAND_SORT_ORDER_MAX = 1_000_000;
export const BRAND_PAGE_SIZE_DEFAULT = 20;
export const BRAND_PAGE_SIZE_MAX = 50;
export const BRAND_LOGO_MAX_BYTES = 2 * 1024 * 1024;

export const BRAND_LOGO_MIME_TYPES = [
  "image/jpeg",
  "image/png",
  "image/webp",
  "image/svg+xml",
] as const;

export type BrandLogoMimeType = (typeof BRAND_LOGO_MIME_TYPES)[number];

export const BRAND_LOGO_EXTENSION_BY_MIME: Record<BrandLogoMimeType, string> = {
  "image/jpeg": ".jpg",
  "image/png": ".png",
  "image/webp": ".webp",
  "image/svg+xml": ".svg",
};

export const BRAND_SLUG_PATTERN = /^[a-z0-9]+(?:-[a-z0-9]+)*$/;
export const UUID_PATTERN =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

export const BRAND_LIST_ORDER = [
  { column: "sort_order", ascending: true },
  { column: "name", ascending: true },
  { column: "id", ascending: true },
] as const;

export const BRAND_AUTH_DENIED_MESSAGE =
  "You do not have permission to manage brands.";
export const BRAND_GENERIC_FAILURE_MESSAGE =
  "We couldn't save that brand. Check your input and try again.";
export const BRAND_LOAD_FAILURE_MESSAGE =
  "We couldn't load brands right now. Try again in a moment.";
export const BRAND_NOT_FOUND_MESSAGE = "That brand could not be found.";
export const BRAND_SLUG_CONFLICT_MESSAGE =
  "That slug is already in use. Choose a different slug.";
export const BRAND_WEBSITE_INVALID_MESSAGE =
  "Enter an absolute HTTPS website URL, or leave the field empty.";
export const BRAND_LOGO_INVALID_MESSAGE =
  "Upload a JPEG, PNG, WebP, or SVG logo up to 2 MiB.";
export const BRAND_LOGO_UPLOAD_FAILURE_MESSAGE =
  "We could not upload that logo. Try a different file.";
export const BRAND_LOGO_CLEANUP_WARNING =
  "The brand was saved, but the previous logo could not be removed automatically.";
export const BRAND_ACTIVATION_CONFIRM_REQUIRED_MESSAGE =
  "Confirm the activation change before continuing.";
export const BRAND_ACTIVATION_SUCCESS_ACTIVE = "Brand activated.";
export const BRAND_ACTIVATION_SUCCESS_INACTIVE = "Brand deactivated.";
export const BRAND_SAVE_SUCCESS_MESSAGE = "Brand saved.";

export const BRAND_SUCCESS_CREATED = "created";
export const BRAND_SUCCESS_UPDATED = "updated";
export const BRAND_SUCCESS_ACTIVATED = "activated";
export const BRAND_SUCCESS_DEACTIVATED = "deactivated";
