export const INVENTORY_LIST_PATH = "/dashboard/inventory";
export const INVENTORY_ROUTE = INVENTORY_LIST_PATH;

export function inventoryAdjustmentPath(variantId: string): string {
  return `${INVENTORY_LIST_PATH}/${variantId}`;
}

export const LIST_CMS_INVENTORY_RPC = "list_cms_inventory";
export const ADJUST_CMS_INVENTORY_RPC = "adjust_cms_inventory";

export const INVENTORY_VARIANT_COLUMNS = "id, product_id, sku, name" as const;
export const INVENTORY_PRODUCT_COLUMNS = "id, name" as const;
export const INVENTORY_ROW_COLUMNS =
  "variant_id, quantity_on_hand, quantity_reserved, reorder_level, allow_backorder, updated_at" as const;
export const INVENTORY_HISTORY_COLUMNS =
  "id, variant_id, actor_id, operation, reason, note, quantity_on_hand_before, quantity_on_hand_after, quantity_reserved_before, quantity_reserved_after, reorder_level_before, reorder_level_after, allow_backorder_before, allow_backorder_after, created_at" as const;
export const INVENTORY_ACTOR_COLUMNS = "id, full_name" as const;

export const INVENTORY_PAGE_SIZE_DEFAULT = 20;
export const INVENTORY_PAGE_SIZE_MAX = 50;
export const INVENTORY_SEARCH_MAX_LENGTH = 80;
export const INVENTORY_HISTORY_LIMIT = 20;
export const INVENTORY_NOTE_MAX_LENGTH = 500;
export const INVENTORY_QUANTITY_MAX = 2_147_483_647;

export const INVENTORY_STOCK_STATES = [
  "all",
  "in_stock",
  "low_stock",
  "out_of_stock",
  "missing",
] as const;

export const INVENTORY_SORTS = [
  "updated_desc",
  "updated_asc",
  "product_asc",
  "product_desc",
  "sku_asc",
  "sku_desc",
  "available_desc",
  "available_asc",
  "on_hand_desc",
  "on_hand_asc",
] as const;

export const INVENTORY_DEFAULT_SORT = "updated_desc" as const;
export const INVENTORY_DEFAULT_STOCK = "all" as const;

export const INVENTORY_OPERATIONS = [
  "add_stock",
  "remove_stock",
  "set_on_hand",
  "set_reorder_level",
  "set_allow_backorder",
] as const;

export const INVENTORY_REASONS = [
  "received",
  "returned",
  "damaged",
  "lost",
  "count_correction",
  "other",
] as const;

export const INVENTORY_STOCK_LABELS = {
  all: "Any stock state",
  in_stock: "In stock",
  low_stock: "Low stock",
  out_of_stock: "Out of stock",
  missing: "Inventory missing",
} as const;

export const INVENTORY_SORT_LABELS = {
  updated_desc: "Newest updated",
  updated_asc: "Oldest updated",
  product_asc: "Product A-Z",
  product_desc: "Product Z-A",
  sku_asc: "SKU A-Z",
  sku_desc: "SKU Z-A",
  available_desc: "Available high-low",
  available_asc: "Available low-high",
  on_hand_desc: "On-hand high-low",
  on_hand_asc: "On-hand low-high",
} as const;

export const INVENTORY_OPERATION_LABELS = {
  add_stock: "Add stock",
  remove_stock: "Remove stock",
  set_on_hand: "Set on-hand",
  set_reorder_level: "Update reorder level",
  set_allow_backorder: "Update allow backorder",
} as const;

export const INVENTORY_REASON_LABELS = {
  received: "Received",
  returned: "Returned",
  damaged: "Damaged",
  lost: "Lost",
  count_correction: "Count correction",
  other: "Other",
} as const;

export const INVENTORY_AUTH_DENIED_MESSAGE =
  "You do not have permission to view inventory.";
export const INVENTORY_MUTATION_AUTH_DENIED_MESSAGE =
  "You do not have permission to adjust inventory.";
export const INVENTORY_LOAD_FAILURE_MESSAGE =
  "We couldn't load inventory right now. Try again in a moment.";
export const INVENTORY_GENERIC_FAILURE_MESSAGE =
  "We couldn't save that inventory adjustment. Check your input and try again.";
export const INVENTORY_NOT_FOUND_MESSAGE = "That variant could not be found.";
export const INVENTORY_QUANTITY_INVALID_MESSAGE =
  "Enter a whole number using digits only.";
export const INVENTORY_QUANTITY_REQUIRED_MESSAGE = "Enter a quantity.";
export const INVENTORY_POSITIVE_QUANTITY_MESSAGE =
  "Enter a whole number of at least 1.";
export const INVENTORY_OPERATION_INVALID_MESSAGE = "Choose a valid operation.";
export const INVENTORY_REASON_INVALID_MESSAGE = "Choose a valid reason.";
export const INVENTORY_NOTE_INVALID_MESSAGE =
  "Keep the note to 500 characters or fewer.";
export const INVENTORY_BACKORDER_INVALID_MESSAGE =
  "Choose whether backorders are allowed.";
export const INVENTORY_FIX_FIELDS_MESSAGE = "Check the highlighted fields.";
export const INVENTORY_SAVE_SUCCESS_MESSAGE = "Inventory adjusted.";
export const INVENTORY_SUCCESS_ADJUSTED = "adjusted";

export const INVENTORY_EXACT_INTEGER_PATTERN = /^(0|[1-9]\d{0,9})$/;
