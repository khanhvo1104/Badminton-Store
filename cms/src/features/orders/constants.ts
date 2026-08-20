export const ORDERS_LIST_PATH = "/dashboard/orders";
export const ORDERS_ROUTE = ORDERS_LIST_PATH;

export function orderDetailPath(orderId: string): string {
  return `${ORDERS_LIST_PATH}/${orderId}`;
}

export const LIST_CMS_ORDERS_RPC = "list_cms_orders";
export const TRANSITION_CMS_ORDER_STATUS_RPC = "transition_cms_order_status";

export const ORDER_LIST_COLUMNS =
  "id, order_number, status, payment_status, currency_code, grand_total, recipient_name, recipient_phone, placed_at" as const;

export const ORDER_DETAIL_COLUMNS =
  "id, order_number, status, payment_method, payment_status, currency_code, subtotal, discount_total, shipping_fee, grand_total, customer_note, recipient_name, recipient_phone, shipping_address, placed_at, cancelled_at, created_at, updated_at" as const;

export const ORDER_ITEM_COLUMNS =
  "id, order_id, product_id, variant_id, product_name, variant_name, sku, image_path, unit_price, quantity, line_total, created_at" as const;

export const ORDER_HISTORY_COLUMNS =
  "id, order_id, from_status, to_status, changed_by, note, created_at" as const;

export const ORDER_ACTOR_COLUMNS = "id, full_name" as const;

export const ORDERS_PAGE_SIZE_DEFAULT = 20;
export const ORDERS_PAGE_SIZE_MAX = 50;
export const ORDERS_SEARCH_MAX_LENGTH = 80;
export const ORDERS_HISTORY_LIMIT = 50;
export const ORDERS_NOTE_MAX_LENGTH = 500;
export const ORDERS_ITEMS_LIMIT = 200;

export const ORDER_STATUSES = [
  "pending",
  "confirmed",
  "preparing",
  "shipping",
  "delivered",
  "cancelled",
  "returned",
] as const;

export const ORDER_STATUS_FILTERS = ["all", ...ORDER_STATUSES] as const;

export const PAYMENT_STATUSES = [
  "unpaid",
  "pending",
  "paid",
  "failed",
  "refunded",
] as const;

export const PAYMENT_STATUS_FILTERS = ["all", ...PAYMENT_STATUSES] as const;

export const ORDER_SORTS = [
  "placed_desc",
  "placed_asc",
  "total_desc",
  "total_asc",
  "number_asc",
  "number_desc",
  "status_asc",
  "status_desc",
] as const;

export const ORDERS_DEFAULT_SORT = "placed_desc" as const;
export const ORDERS_DEFAULT_STATUS = "all" as const;
export const ORDERS_DEFAULT_PAYMENT_STATUS = "all" as const;

export const ORDER_STATUS_LABELS = {
  all: "Any status",
  pending: "Pending",
  confirmed: "Confirmed",
  preparing: "Preparing",
  shipping: "Shipping",
  delivered: "Delivered",
  cancelled: "Cancelled",
  returned: "Returned",
} as const;

export const PAYMENT_STATUS_LABELS = {
  all: "Any payment status",
  unpaid: "Unpaid",
  pending: "Pending",
  paid: "Paid",
  failed: "Failed",
  refunded: "Refunded",
} as const;

export const ORDER_SORT_LABELS = {
  placed_desc: "Newest placed",
  placed_asc: "Oldest placed",
  total_desc: "Total high-low",
  total_asc: "Total low-high",
  number_asc: "Order number A-Z",
  number_desc: "Order number Z-A",
  status_asc: "Status A-Z",
  status_desc: "Status Z-A",
} as const;

export const ORDER_TRANSITIONS = {
  pending: ["confirmed", "cancelled"],
  confirmed: ["preparing", "cancelled"],
  preparing: ["shipping", "cancelled"],
  shipping: ["delivered"],
  delivered: ["returned"],
  cancelled: [],
  returned: [],
} as const;

export const ORDERS_AUTH_DENIED_MESSAGE =
  "You do not have permission to view orders.";
export const ORDERS_MUTATION_AUTH_DENIED_MESSAGE =
  "You do not have permission to update order status.";
export const ORDERS_LOAD_FAILURE_MESSAGE =
  "We couldn't load orders right now. Try again in a moment.";
export const ORDERS_GENERIC_FAILURE_MESSAGE =
  "We couldn't update that order status. Check your input and try again.";
export const ORDERS_NOT_FOUND_MESSAGE = "That order could not be found.";
export const ORDERS_STATUS_INVALID_MESSAGE = "Choose a valid next status.";
export const ORDERS_NOTE_INVALID_MESSAGE =
  "Keep the note to 500 characters or fewer.";
export const ORDERS_CONFIRM_REQUIRED_MESSAGE =
  "Confirm the status change before saving.";
export const ORDERS_FIX_FIELDS_MESSAGE = "Check the highlighted fields.";
export const ORDERS_SAVE_SUCCESS_MESSAGE = "Order status updated.";
export const ORDERS_SUCCESS_TRANSITIONED = "transitioned";

export const SHIPPING_SNAPSHOT_KEYS = [
  "recipient_name",
  "phone_number",
  "province_name",
  "district_name",
  "ward_name",
  "street_address",
  "address_note",
] as const;
