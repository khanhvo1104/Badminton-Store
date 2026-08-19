export const PRODUCT_IMAGES_BUCKET = "product-images";
export const SET_CMS_PRODUCT_IMAGE_PRIMARY_RPC =
  "set_cms_product_image_primary";
export const REORDER_CMS_PRODUCT_IMAGES_RPC = "reorder_cms_product_images";
export const INSERT_CMS_PRODUCT_IMAGE_RPC = "insert_cms_product_image";
export const UPDATE_CMS_PRODUCT_IMAGE_RPC = "update_cms_product_image";

export const PRODUCT_IMAGE_LIST_COLUMNS =
  "id, product_id, variant_id, storage_path, alt_text, sort_order, is_primary, updated_at" as const;

export const PRODUCT_IMAGE_VARIANT_COLUMNS = "id, sku, name" as const;

export const PRODUCT_IMAGE_MAX_COUNT = 20;
export const PRODUCT_IMAGE_MAX_BYTES = 5 * 1024 * 1024;
export const PRODUCT_IMAGE_ALT_MAX_LENGTH = 200;
export const PRODUCT_IMAGE_SORT_ORDER_MIN = -1_000_000;
export const PRODUCT_IMAGE_SORT_ORDER_MAX = 1_000_000;

export const PRODUCT_IMAGE_MIME_TYPES = [
  "image/jpeg",
  "image/png",
  "image/webp",
  "image/gif",
] as const;

export type ProductImageMimeType = (typeof PRODUCT_IMAGE_MIME_TYPES)[number];

export const PRODUCT_IMAGE_EXTENSION_BY_MIME: Record<
  ProductImageMimeType,
  string
> = {
  "image/jpeg": ".jpg",
  "image/png": ".png",
  "image/webp": ".webp",
  "image/gif": ".gif",
};

export const UUID_PATTERN =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

export const MEDIA_AUTH_DENIED_MESSAGE =
  "You do not have permission to manage product images.";
export const MEDIA_GENERIC_FAILURE_MESSAGE =
  "We couldn't save that image. Check your input and try again.";
export const MEDIA_LOAD_FAILURE_MESSAGE =
  "We couldn't load product images right now. Try again in a moment.";
export const MEDIA_NOT_FOUND_MESSAGE = "That image could not be found.";
export const MEDIA_PRODUCT_NOT_FOUND_MESSAGE =
  "That product could not be found.";
export const MEDIA_IMAGE_INVALID_MESSAGE =
  "Upload a JPEG, PNG, WebP, or GIF image up to 5 MiB.";
export const MEDIA_IMAGE_REQUIRED_MESSAGE = "Choose an image file to upload.";
export const MEDIA_IMAGE_UPLOAD_FAILURE_MESSAGE =
  "We could not upload that image. Try a different file.";
export const MEDIA_IMAGE_CLEANUP_WARNING =
  "The image was saved, but the previous file could not be removed automatically.";
export const MEDIA_DELETE_CLEANUP_WARNING =
  "The image record was removed, but the stored file could not be deleted automatically.";
export const MEDIA_COUNT_LIMIT_MESSAGE =
  "This product already has the maximum of 20 images.";
export const MEDIA_ALT_INVALID_MESSAGE =
  "Alt text must be 200 characters or fewer.";
export const MEDIA_VARIANT_INVALID_MESSAGE =
  "Choose a variant that belongs to this product, or leave the field empty.";
export const MEDIA_SORT_ORDER_INVALID_MESSAGE =
  "Enter a whole number between -1000000 and 1000000.";
export const MEDIA_REORDER_INVALID_MESSAGE =
  "Image order must include every image for this product and no others.";
export const MEDIA_DELETE_CONFIRM_REQUIRED_MESSAGE =
  "Confirm the deletion before continuing.";
export const MEDIA_PRIMARY_SUCCESS_MESSAGE = "Primary image updated.";
export const MEDIA_UPLOAD_SUCCESS_MESSAGE = "Image uploaded.";
export const MEDIA_UPDATE_SUCCESS_MESSAGE = "Image details saved.";
export const MEDIA_REPLACE_SUCCESS_MESSAGE = "Image replaced.";
export const MEDIA_DELETE_SUCCESS_MESSAGE = "Image deleted.";
export const MEDIA_REORDER_SUCCESS_MESSAGE = "Image order saved.";

export const MEDIA_SUCCESS_UPLOADED = "uploaded";
export const MEDIA_SUCCESS_UPDATED = "updated";
export const MEDIA_SUCCESS_REPLACED = "replaced";
export const MEDIA_SUCCESS_PRIMARY = "primary";
export const MEDIA_SUCCESS_DELETED = "deleted";
export const MEDIA_SUCCESS_REORDERED = "reordered";

export function productMediaPath(productId: string): string {
  return `/dashboard/products/${productId}/media`;
}
