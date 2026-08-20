import type {
  ORDER_SORTS,
  ORDER_STATUSES,
  ORDER_STATUS_FILTERS,
  PAYMENT_STATUSES,
  PAYMENT_STATUS_FILTERS,
} from "@/features/orders/constants";

export type OrderStatus = (typeof ORDER_STATUSES)[number];
export type OrderStatusFilter = (typeof ORDER_STATUS_FILTERS)[number];
export type PaymentStatus = (typeof PAYMENT_STATUSES)[number];
export type PaymentStatusFilter = (typeof PAYMENT_STATUS_FILTERS)[number];
export type OrderSort = (typeof ORDER_SORTS)[number];

export type OrdersPagination = {
  page: number;
  pageSize: number;
  from: number;
  to: number;
};

export type OrdersExplorerQuery = {
  search: string;
  status: OrderStatusFilter;
  paymentStatus: PaymentStatusFilter;
  placedFrom: string | null;
  placedTo: string | null;
  sort: OrderSort;
  pagination: OrdersPagination;
};

export type OrderListItem = {
  orderId: string;
  orderNumber: string;
  status: OrderStatus;
  statusLabel: string;
  paymentStatus: PaymentStatus;
  paymentStatusLabel: string;
  currencyCode: string;
  grandTotal: number;
  grandTotalLabel: string;
  recipientName: string;
  recipientPhone: string;
  placedAt: string;
  placedAtLabel: string;
  itemCount: number;
};

export type OrdersListResult = {
  items: OrderListItem[];
  totalCount: number;
  pagination: OrdersPagination;
  totalPages: number;
  query: OrdersExplorerQuery;
  hasActiveFilters: boolean;
};

export type OrdersExplorerLoadResult =
  | { ok: true; result: OrdersListResult }
  | { ok: false; message: string };

export type OrderShippingSnapshot = {
  recipientName: string | null;
  phoneNumber: string | null;
  provinceName: string | null;
  districtName: string | null;
  wardName: string | null;
  streetAddress: string | null;
  addressNote: string | null;
};

export type OrderItemSnapshot = {
  id: string;
  productName: string;
  variantName: string | null;
  sku: string;
  unitPrice: number;
  unitPriceLabel: string;
  quantity: number;
  lineTotal: number;
  lineTotalLabel: string;
};

export type OrderHistoryItem = {
  id: string;
  fromStatus: OrderStatus | null;
  fromStatusLabel: string | null;
  toStatus: OrderStatus;
  toStatusLabel: string;
  note: string | null;
  actorName: string;
  createdAt: string;
  createdAtLabel: string;
};

export type OrderDetail = {
  orderId: string;
  orderNumber: string;
  status: OrderStatus;
  statusLabel: string;
  paymentMethod: string;
  paymentStatus: PaymentStatus;
  paymentStatusLabel: string;
  currencyCode: string;
  subtotal: number;
  subtotalLabel: string;
  discountTotal: number;
  discountTotalLabel: string;
  shippingFee: number;
  shippingFeeLabel: string;
  grandTotal: number;
  grandTotalLabel: string;
  customerNote: string | null;
  recipientName: string;
  recipientPhone: string;
  shipping: OrderShippingSnapshot;
  placedAt: string;
  placedAtLabel: string;
  cancelledAt: string | null;
  cancelledAtLabel: string | null;
  nextStatuses: OrderStatus[];
  items: OrderItemSnapshot[];
  history: OrderHistoryItem[];
};

export type OrderDetailLoadResult =
  | { ok: true; detail: OrderDetail }
  | { ok: false; message: string; notFound?: boolean };

export type OrderTransitionFormValues = {
  toStatus: string;
  note: string;
  confirmed: string;
};

export type OrderTransitionFieldErrors = {
  toStatus?: string;
  note?: string;
  confirmed?: string;
};

export type OrderTransitionFormState = {
  status: "idle" | "error";
  message: string | null;
  fieldErrors: OrderTransitionFieldErrors;
  values: OrderTransitionFormValues;
};

export type ParsedOrderTransition = {
  toStatus: OrderStatus;
  note: string | null;
};
