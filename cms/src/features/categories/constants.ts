export const CATEGORIES_LIST_PATH = "/dashboard/categories";
export const CATEGORIES_ROUTE = CATEGORIES_LIST_PATH;
export const CATEGORIES_NEW_PATH = "/dashboard/categories/new";

export function categoryEditPath(categoryId: string): string {
  return `${CATEGORIES_LIST_PATH}/${categoryId}/edit`;
}

export const CATEGORY_LIST_COLUMNS =
  "id, parent_id, name, slug, description, image_path, sort_order, is_active" as const;

export const CATEGORY_DETAIL_COLUMNS = CATEGORY_LIST_COLUMNS;

export const CATEGORY_PARENT_OPTION_COLUMNS =
  "id, parent_id, name, is_active" as const;

export const CATEGORY_ASSETS_BUCKET = "category-assets";

export const CATEGORY_NAME_MAX_LENGTH = 120;
export const CATEGORY_SLUG_MAX_LENGTH = 120;
export const CATEGORY_DESCRIPTION_MAX_LENGTH = 2000;
export const CATEGORY_SORT_ORDER_MIN = -1_000_000;
export const CATEGORY_SORT_ORDER_MAX = 1_000_000;
export const CATEGORY_PAGE_SIZE_DEFAULT = 20;
export const CATEGORY_PAGE_SIZE_MAX = 50;
export const CATEGORY_GRAPH_FETCH_LIMIT = 2000;
export const CATEGORY_HIERARCHY_MAX_NODES = 500;
export const CATEGORY_IMAGE_MAX_BYTES = 2 * 1024 * 1024;

export const CATEGORY_IMAGE_MIME_TYPES = [
  "image/jpeg",
  "image/png",
  "image/webp",
  "image/svg+xml",
] as const;

export type CategoryImageMimeType = (typeof CATEGORY_IMAGE_MIME_TYPES)[number];

export const CATEGORY_IMAGE_EXTENSION_BY_MIME: Record<
  CategoryImageMimeType,
  string
> = {
  "image/jpeg": ".jpg",
  "image/png": ".png",
  "image/webp": ".webp",
  "image/svg+xml": ".svg",
};

export const CATEGORY_SLUG_PATTERN = /^[a-z0-9]+(?:-[a-z0-9]+)*$/;
export const UUID_PATTERN =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

export const CATEGORY_LIST_ORDER = [
  { column: "sort_order", ascending: true },
  { column: "name", ascending: true },
  { column: "id", ascending: true },
] as const;

export const CATEGORY_AUTH_DENIED_MESSAGE =
  "You do not have permission to manage categories.";
export const CATEGORY_GENERIC_FAILURE_MESSAGE =
  "We couldn't save that category. Check your input and try again.";
export const CATEGORY_LOAD_FAILURE_MESSAGE =
  "We couldn't load categories right now. Try again in a moment.";
export const CATEGORY_NOT_FOUND_MESSAGE = "That category could not be found.";
export const CATEGORY_SLUG_CONFLICT_MESSAGE =
  "That slug is already in use. Choose a different slug.";
export const CATEGORY_PARENT_INVALID_MESSAGE =
  "Choose a valid parent category, or leave parent empty.";
export const CATEGORY_PARENT_CYCLE_MESSAGE =
  "A category cannot use itself or one of its descendants as its parent.";
export const CATEGORY_IMAGE_INVALID_MESSAGE =
  "Upload a JPEG, PNG, WebP, or SVG image up to 2 MiB.";
export const CATEGORY_IMAGE_UPLOAD_FAILURE_MESSAGE =
  "We could not upload that image. Try a different file.";
export const CATEGORY_IMAGE_CLEANUP_WARNING =
  "The category was saved, but the previous image could not be removed automatically.";
export const CATEGORY_ACTIVATION_CONFIRM_REQUIRED_MESSAGE =
  "Confirm the activation change before continuing.";
export const CATEGORY_ACTIVATION_SUCCESS_ACTIVE = "Category activated.";
export const CATEGORY_ACTIVATION_SUCCESS_INACTIVE = "Category deactivated.";
export const CATEGORY_SAVE_SUCCESS_MESSAGE = "Category saved.";

export const CATEGORY_SUCCESS_CREATED = "created";
export const CATEGORY_SUCCESS_UPDATED = "updated";
export const CATEGORY_SUCCESS_ACTIVATED = "activated";
export const CATEGORY_SUCCESS_DEACTIVATED = "deactivated";
