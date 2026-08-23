import type { DASHBOARD_RANGE_DAYS } from "@/features/operational-dashboard/constants";

export type DashboardRangeDays = (typeof DASHBOARD_RANGE_DAYS)[number];

export type DashboardQuery = {
  rangeDays: DashboardRangeDays;
};

export type DashboardCurrencyGross = {
  currencyCode: string;
  grossOrderValue: number;
  grossOrderValueLabel: string;
};

export type DashboardStatusBreakdownItem = {
  status: keyof typeof import("@/features/operational-dashboard/constants").ORDER_STATUS_LABELS;
  orderCount: number;
  statusLabel: string;
};

export type DashboardDailyPoint = {
  date: string;
  orderCount: number;
  grossOrderValue: number;
  grossOrderValueLabel: string;
};

export type DashboardDailySeriesByCurrency = {
  currencyCode: string;
  series: DashboardDailyPoint[];
};

export type DashboardLowStockVariant = {
  variantId: string;
  productId: string;
  productName: string;
  variantName: string | null;
  sku: string;
  quantityOnHand: number;
  quantityReserved: number;
  quantityAvailable: number;
  reorderLevel: number;
  allowBackorder: boolean;
};

export type OperationalDashboardSnapshot = {
  rangeDays: DashboardRangeDays;
  windowStart: string;
  windowEnd: string;
  windowStartLabel: string;
  windowEndLabel: string;
  totalOrders: number;
  grossOrderValueByCurrency: DashboardCurrencyGross[];
  deliveredOrders: number;
  openFulfillmentCount: number;
  statusBreakdown: DashboardStatusBreakdownItem[];
  dailySeriesByCurrency: DashboardDailySeriesByCurrency[];
  lowStockVariants: DashboardLowStockVariant[];
};

export type OperationalDashboardLoadResult =
  | { ok: true; snapshot: OperationalDashboardSnapshot }
  | { ok: false; message: string };
