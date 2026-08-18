export const VARIANT_SAFE_COLUMNS =
  "id, product_id, sku, name, color_name, color_hex, racket_weight_class, grip_size, shoe_size, clothing_size, unit, price, compare_at_price, attributes, is_default, is_active, sort_order" as const;

export const GET_STAFF_VARIANT_COSTS_RPC = "get_staff_variant_costs";
export const SAVE_CMS_PRODUCT_VARIANT_RPC = "save_cms_product_variant";

export const VARIANT_LIST_MAX = 200;

export const VARIANT_SKU_MAX_LENGTH = 80;
export const VARIANT_NAME_MAX_LENGTH = 200;
export const VARIANT_COLOR_NAME_MAX_LENGTH = 80;
export const VARIANT_SPORT_ATTR_MAX_LENGTH = 40;
export const VARIANT_UNIT_MAX_LENGTH = 40;
export const VARIANT_BARCODE_MAX_LENGTH = 80;
export const VARIANT_SORT_ORDER_MIN = -1_000_000;
export const VARIANT_SORT_ORDER_MAX = 1_000_000;

export const VARIANT_ATTR_MAX_KEYS = 50;
export const VARIANT_ATTR_MAX_DEPTH = 3;
export const VARIANT_ATTR_MAX_KEY_LENGTH = 80;
export const VARIANT_ATTR_MAX_STRING_VALUE_LENGTH = 500;
export const VARIANT_ATTR_MAX_SERIALIZED_BYTES = 8192;

export const VARIANT_COLOR_HEX_PATTERN = /^#[0-9A-Fa-f]{6}$/;
export const VARIANT_MONEY_PATTERN = /^(?:0|[1-9]\d{0,11})(?:\.\d{1,2})?$/;

export const VARIANT_COST_MODES = ["unchanged", "clear", "set"] as const;
export const VARIANT_BARCODE_MODES = ["unchanged", "clear", "set"] as const;

/**
 * SKU normalization rule (CMS + save_cms_product_variant):
 * 1. Trim leading and trailing whitespace.
 * 2. Collapse every internal whitespace run to a single ASCII space.
 * 3. Preserve case.
 * 4. Reject empty values and values longer than 80 characters.
 */
export function normalizeVariantSku(raw: string): string {
  return raw.trim().replace(/\s+/g, " ");
}

export function normalizeOptionalVariantText(raw: string): string {
  return raw.trim().replace(/\s+/g, " ");
}

export const VARIANT_AUTH_DENIED_MESSAGE =
  "You do not have permission to manage variants.";
export const VARIANT_LOAD_FAILURE_MESSAGE =
  "We couldn't load variants right now. Try again in a moment.";
export const VARIANT_GENERIC_FAILURE_MESSAGE =
  "We couldn't save that variant. Check your input and try again.";
export const VARIANT_NOT_FOUND_MESSAGE = "That variant could not be found.";
export const VARIANT_PRODUCT_NOT_FOUND_MESSAGE =
  "That product could not be found.";
export const VARIANT_SKU_CONFLICT_MESSAGE =
  "That SKU is already in use. Choose a different SKU.";
export const VARIANT_BARCODE_CONFLICT_MESSAGE =
  "That barcode is already in use. Choose a different barcode.";
export const VARIANT_COMPARE_RULE_MESSAGE =
  "Compare-at price must be greater than or equal to the selling price.";
export const VARIANT_DEFAULT_LOCKED_MESSAGE =
  "This variant is the current default. Choose another variant as default instead of turning this one off.";
export const VARIANT_BOOLEAN_INVALID_MESSAGE = "Choose yes or no.";
export const VARIANT_ATTRIBUTES_INVALID_MESSAGE =
  "Attributes must be a JSON object with bounded nested keys and values.";
export const VARIANT_PRICE_INVALID_MESSAGE =
  "Enter a nonnegative price with at most 12 digits before the decimal and 2 after.";
export const VARIANT_COST_INVALID_MESSAGE =
  "Enter a nonnegative cost with at most 12 digits before the decimal and 2 after, or leave the field empty to clear it.";
export const VARIANT_COLOR_HEX_INVALID_MESSAGE =
  "Color hex must be empty or a #RRGGBB value.";
export const VARIANT_FIX_FIELDS_MESSAGE =
  "Fix the highlighted fields and try again.";

export const VARIANT_SUCCESS_CREATED = "created";
export const VARIANT_SUCCESS_UPDATED = "updated";
export const VARIANT_SAVE_SUCCESS_MESSAGE = "Variant saved.";

export const VARIANT_NO_COST_LABEL = "Not recorded";

export function productVariantsPath(productId: string): string {
  return `/dashboard/products/${productId}/variants`;
}

export function productVariantNewPath(productId: string): string {
  return `/dashboard/products/${productId}/variants/new`;
}

export function productVariantEditPath(
  productId: string,
  variantId: string,
): string {
  return `/dashboard/products/${productId}/variants/${variantId}/edit`;
}
