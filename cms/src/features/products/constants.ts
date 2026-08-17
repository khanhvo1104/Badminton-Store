export const PRODUCTS_LIST_PATH = "/dashboard/products";
export const PRODUCTS_ROUTE = PRODUCTS_LIST_PATH;
export const LIST_CMS_PRODUCTS_RPC = "list_cms_products";

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
export const PRODUCT_LOAD_FAILURE_MESSAGE =
  "We couldn't load products right now. Try again in a moment.";
export const PRODUCT_NO_PRICE_LABEL = "No price";
export const PRODUCT_NO_INVENTORY_LABEL = "Inventory incomplete";
export const PRODUCT_EDITOR_UNAVAILABLE_LABEL = "Editor unavailable";
export const PRODUCT_EDITOR_UNAVAILABLE_HELP =
  "The product editor arrives in a later catalog task.";
