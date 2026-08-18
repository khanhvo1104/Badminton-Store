export const PRODUCTS_LIST_PATH = "/dashboard/products";
export const PRODUCTS_ROUTE = PRODUCTS_LIST_PATH;
export const PRODUCTS_NEW_PATH = "/dashboard/products/new";

export function productEditPath(productId: string): string {
  return `${PRODUCTS_LIST_PATH}/${productId}/edit`;
}

export function productDetailPath(productId: string): string {
  return `${PRODUCTS_LIST_PATH}/${productId}`;
}

export const LIST_CMS_PRODUCTS_RPC = "list_cms_products";

export const PRODUCT_DETAIL_COLUMNS =
  "id, category_id, brand_id, name, slug, short_description, description, specifications, search_keywords, status, is_featured, published_at, updated_at" as const;

export const PRODUCT_MUTATION_COLUMNS = PRODUCT_DETAIL_COLUMNS;

export const PRODUCT_NAME_MAX_LENGTH = 200;
export const PRODUCT_SLUG_MAX_LENGTH = 120;
export const PRODUCT_SHORT_DESCRIPTION_MAX_LENGTH = 500;
export const PRODUCT_DESCRIPTION_MAX_LENGTH = 10_000;
export const PRODUCT_SEARCH_KEYWORDS_MAX_LENGTH = 500;
export const PRODUCT_SPEC_MAX_KEYS = 50;
export const PRODUCT_SPEC_MAX_DEPTH = 3;
export const PRODUCT_SPEC_MAX_KEY_LENGTH = 80;
export const PRODUCT_SPEC_MAX_STRING_VALUE_LENGTH = 500;
export const PRODUCT_SPEC_MAX_SERIALIZED_BYTES = 8192;

export const PRODUCT_SLUG_PATTERN = /^[a-z0-9]+(?:-[a-z0-9]+)*$/;

export const PRODUCT_IMAGE_LIST_COLUMNS =
  "product_id, storage_path, variant_id, is_primary" as const;

export const PRODUCT_FILTER_OPTION_COLUMNS = "id, name, is_active" as const;

export const PRODUCT_NAME_LOOKUP_COLUMNS = "id, name" as const;

export const PRODUCT_IMAGES_BUCKET = "product-images";

export const PRODUCT_PAGE_SIZE_DEFAULT = 20;
export const PRODUCT_PAGE_SIZE_MAX = 50;
export const PRODUCT_SEARCH_MAX_LENGTH = 80;
export const PRODUCT_FILTER_OPTION_LIMIT = 2000;
export const PRODUCT_RELATED_FETCH_LIMIT = 1000;

export const UUID_PATTERN =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

export const PRODUCT_STATUSES = [
  "draft",
  "active",
  "inactive",
  "archived",
] as const;

export const PRODUCT_STOCK_STATES = [
  "all",
  "in_stock",
  "low_stock",
  "out_of_stock",
  "missing",
] as const;

export const PRODUCT_SORTS = [
  "updated_desc",
  "updated_asc",
  "name_asc",
  "name_desc",
  "price_asc",
  "price_desc",
] as const;

export const PRODUCT_DEFAULT_SORT = "updated_desc" as const;
export const PRODUCT_DEFAULT_STOCK = "all" as const;

export const PRODUCT_LIST_ORDER = {
  updated_desc: [
    { column: "updated_at", ascending: false },
    { column: "id", ascending: true },
  ],
  updated_asc: [
    { column: "updated_at", ascending: true },
    { column: "id", ascending: true },
  ],
  name_asc: [
    { column: "name", ascending: true },
    { column: "id", ascending: true },
  ],
  name_desc: [
    { column: "name", ascending: false },
    { column: "id", ascending: true },
  ],
  price_asc: [{ column: "id", ascending: true }],
  price_desc: [{ column: "id", ascending: true }],
} as const;

export const PRODUCT_STATUS_LABELS = {
  draft: "Draft",
  active: "Active",
  inactive: "Inactive",
  archived: "Archived",
} as const;

export const PRODUCT_STOCK_LABELS = {
  all: "Any stock state",
  in_stock: "In stock",
  low_stock: "Low stock",
  out_of_stock: "Out of stock",
  missing: "Inventory incomplete",
} as const;

export const PRODUCT_SORT_LABELS = {
  updated_desc: "Newest updated",
  updated_asc: "Oldest updated",
  name_asc: "Name A-Z",
  name_desc: "Name Z-A",
  price_asc: "Price low-high",
  price_desc: "Price high-low",
} as const;

export const PRODUCT_AUTH_DENIED_MESSAGE =
  "You do not have permission to view products.";
export const PRODUCT_MUTATION_AUTH_DENIED_MESSAGE =
  "You do not have permission to manage products.";
export const PRODUCT_LOAD_FAILURE_MESSAGE =
  "We couldn't load products right now. Try again in a moment.";
export const PRODUCT_GENERIC_FAILURE_MESSAGE =
  "We couldn't save that product. Check your input and try again.";
export const PRODUCT_NOT_FOUND_MESSAGE = "That product could not be found.";
export const PRODUCT_SLUG_CONFLICT_MESSAGE =
  "That slug is already in use. Choose a different slug.";
export const PRODUCT_INACTIVE_CATEGORY_MESSAGE =
  "Choose an active category, or keep the current inactive category on this product.";
export const PRODUCT_INACTIVE_BRAND_MESSAGE =
  "Choose an active brand, or keep the current inactive brand on this product.";
export const PRODUCT_CATEGORY_REQUIRED_MESSAGE = "Choose a category.";
export const PRODUCT_PUBLISH_INACTIVE_CATEGORY_MESSAGE =
  "Active products require an active category.";
export const PRODUCT_PUBLISH_INACTIVE_BRAND_MESSAGE =
  "Active products require an active brand.";
export const PRODUCT_SPEC_INVALID_MESSAGE =
  "Specifications must be a JSON object with bounded keys and values.";
export const PRODUCT_PUBLISHED_AT_INVALID_MESSAGE =
  "Enter a valid publication date and time, or leave the field empty.";
export const PRODUCT_SAVE_SUCCESS_MESSAGE = "Product saved.";

export const PRODUCT_SUCCESS_CREATED = "created";
export const PRODUCT_SUCCESS_UPDATED = "updated";

export const PRODUCT_NO_PRICE_LABEL = "No price";
export const PRODUCT_NO_INVENTORY_LABEL = "Inventory incomplete";
