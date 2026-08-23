export const DASHBOARD_OVERVIEW_PATH = "/dashboard";

export const GET_CMS_OPERATIONAL_DASHBOARD_RPC =
  "get_cms_operational_dashboard";

export const DASHBOARD_RANGE_DAYS = [7, 30, 90] as const;
export const DASHBOARD_DEFAULT_RANGE_DAYS = 30;

export const DASHBOARD_MAX_CURRENCIES = 20;
export const DASHBOARD_MAX_LOW_STOCK_VARIANTS = 10;
export const DASHBOARD_MAX_DAILY_POINTS = 90;

export const DASHBOARD_AUTH_DENIED_MESSAGE =
  "You do not have permission to view operational dashboard metrics.";
export const DASHBOARD_LOAD_FAILURE_MESSAGE =
  "Operational dashboard metrics could not be loaded.";
export const DASHBOARD_GENERIC_FAILURE_MESSAGE =
  "Something went wrong while loading dashboard metrics.";

export const ORDER_STATUS_LABELS = {
  pending: "Pending",
  confirmed: "Confirmed",
  preparing: "Preparing",
  shipping: "Shipping",
  delivered: "Delivered",
  cancelled: "Cancelled",
  returned: "Returned",
} as const;

export const DASHBOARD_RPC_ROW_KEYS = [
  "range_days",
  "window_start",
  "window_end",
  "total_orders",
  "gross_order_value_by_currency",
  "delivered_orders",
  "open_fulfillment_count",
  "status_breakdown",
  "daily_series_by_currency",
  "low_stock_variants",
] as const;

export const DASHBOARD_FORBIDDEN_RPC_KEYS = [
  "user_id",
  "cost_price",
  "recipient_name",
  "recipient_phone",
  "shipping_address",
  "customer_note",
  "barcode",
] as const;
