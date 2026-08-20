import {
  ORDER_STATUS_LABELS,
  PAYMENT_STATUS_LABELS,
} from "@/features/orders/constants";
import type {
  OrderDetail,
  OrderHistoryItem,
  OrderItemSnapshot,
  OrderListItem,
  OrderShippingSnapshot,
  OrderStatus,
  PaymentStatus,
} from "@/features/orders/types";
import {
  getNextOrderStatuses,
  isOrderStatus,
} from "@/features/orders/validation";
import { isValidUuid } from "@/features/products/validation";

const TRANSITION_RESULT_KEYS = ["order_id"] as const;

export type CmsOrderRpcRow = {
  order_id: string | null;
  order_number: string | null;
  status: string | null;
  payment_status: string | null;
  currency_code: string | null;
  grand_total: number | null;
  recipient_name: string | null;
  recipient_phone: string | null;
  placed_at: string | null;
  item_count: number | null;
  filtered_count: number;
};

export function readTransitionedOrderId(
  data: unknown,
  expectedOrderId: string,
): string | null {
  if (!isValidUuid(expectedOrderId)) {
    return null;
  }
  if (!Array.isArray(data) || data.length !== 1) {
    return null;
  }

  const row = data[0];
  if (!isRecord(row)) {
    return null;
  }

  const keys = Object.keys(row);
  if (
    keys.length !== TRANSITION_RESULT_KEYS.length ||
    keys[0] !== "order_id" ||
    !Object.prototype.hasOwnProperty.call(row, "order_id")
  ) {
    return null;
  }
  if (typeof row.order_id !== "string" || !isValidUuid(row.order_id)) {
    return null;
  }
  if (row.order_id !== expectedOrderId) {
    return null;
  }
  return row.order_id;
}

export function mapCmsOrderRpcRow(value: unknown): CmsOrderRpcRow | null {
  if (!isRecord(value)) {
    return null;
  }

  const filteredCount = asInteger(value.filtered_count);
  if (filteredCount === null || filteredCount < 0) {
    return null;
  }

  if (value.order_id == null) {
    return {
      order_id: null,
      order_number: null,
      status: null,
      payment_status: null,
      currency_code: null,
      grand_total: null,
      recipient_name: null,
      recipient_phone: null,
      placed_at: null,
      item_count: null,
      filtered_count: filteredCount,
    };
  }

  if (
    typeof value.order_id !== "string" ||
    typeof value.order_number !== "string" ||
    typeof value.status !== "string" ||
    typeof value.payment_status !== "string" ||
    typeof value.currency_code !== "string" ||
    typeof value.recipient_name !== "string" ||
    typeof value.recipient_phone !== "string" ||
    typeof value.placed_at !== "string"
  ) {
    return null;
  }

  const grandTotal = asMoney(value.grand_total);
  const itemCount = asInteger(value.item_count);
  if (grandTotal === null || itemCount === null || itemCount < 0) {
    return null;
  }

  return {
    order_id: value.order_id,
    order_number: value.order_number,
    status: value.status,
    payment_status: value.payment_status,
    currency_code: value.currency_code,
    grand_total: grandTotal,
    recipient_name: value.recipient_name,
    recipient_phone: value.recipient_phone,
    placed_at: value.placed_at,
    item_count: itemCount,
    filtered_count: filteredCount,
  };
}

export function mapOrderListItem(
  row: CmsOrderRpcRow & { order_id: string },
): OrderListItem | null {
  if (
    !isOrderStatus(row.status ?? "") ||
    !isPaymentStatus(row.payment_status ?? "") ||
    typeof row.order_number !== "string" ||
    typeof row.currency_code !== "string" ||
    typeof row.recipient_name !== "string" ||
    typeof row.recipient_phone !== "string" ||
    typeof row.placed_at !== "string" ||
    row.grand_total === null ||
    row.item_count === null
  ) {
    return null;
  }

  return {
    orderId: row.order_id,
    orderNumber: row.order_number,
    status: row.status as OrderStatus,
    statusLabel: ORDER_STATUS_LABELS[row.status as OrderStatus],
    paymentStatus: row.payment_status as PaymentStatus,
    paymentStatusLabel:
      PAYMENT_STATUS_LABELS[row.payment_status as PaymentStatus],
    currencyCode: row.currency_code,
    grandTotal: row.grand_total,
    grandTotalLabel: formatMoney(row.grand_total, row.currency_code),
    recipientName: row.recipient_name,
    recipientPhone: row.recipient_phone,
    placedAt: row.placed_at,
    placedAtLabel: formatDateTime(row.placed_at),
    itemCount: row.item_count,
  };
}

export function mapOrderDetailRow(value: unknown): {
  id: string;
  order_number: string;
  status: OrderStatus;
  payment_method: string;
  payment_status: PaymentStatus;
  currency_code: string;
  subtotal: number;
  discount_total: number;
  shipping_fee: number;
  grand_total: number;
  customer_note: string | null;
  recipient_name: string;
  recipient_phone: string;
  shipping_address: unknown;
  placed_at: string;
  cancelled_at: string | null;
} | null {
  if (!isRecord(value)) {
    return null;
  }
  if (
    typeof value.id !== "string" ||
    typeof value.order_number !== "string" ||
    typeof value.status !== "string" ||
    typeof value.payment_method !== "string" ||
    typeof value.payment_status !== "string" ||
    typeof value.currency_code !== "string" ||
    typeof value.recipient_name !== "string" ||
    typeof value.recipient_phone !== "string" ||
    typeof value.placed_at !== "string" ||
    !isOrderStatus(value.status) ||
    !isPaymentStatus(value.payment_status)
  ) {
    return null;
  }

  const subtotal = asMoney(value.subtotal);
  const discountTotal = asMoney(value.discount_total);
  const shippingFee = asMoney(value.shipping_fee);
  const grandTotal = asMoney(value.grand_total);
  if (
    subtotal === null ||
    discountTotal === null ||
    shippingFee === null ||
    grandTotal === null
  ) {
    return null;
  }

  return {
    id: value.id,
    order_number: value.order_number,
    status: value.status,
    payment_method: value.payment_method,
    payment_status: value.payment_status,
    currency_code: value.currency_code,
    subtotal,
    discount_total: discountTotal,
    shipping_fee: shippingFee,
    grand_total: grandTotal,
    customer_note: asNullableString(value.customer_note),
    recipient_name: value.recipient_name,
    recipient_phone: value.recipient_phone,
    shipping_address: value.shipping_address,
    placed_at: value.placed_at,
    cancelled_at: asNullableString(value.cancelled_at),
  };
}

export function mapOrderItemRow(
  value: unknown,
  currencyCode: string,
): OrderItemSnapshot | null {
  if (!isRecord(value)) {
    return null;
  }
  if (
    typeof value.id !== "string" ||
    typeof value.product_name !== "string" ||
    typeof value.sku !== "string" ||
    typeof currencyCode !== "string" ||
    currencyCode.length !== 3
  ) {
    return null;
  }

  const unitPrice = asMoney(value.unit_price);
  const quantity = asInteger(value.quantity);
  const lineTotal = asMoney(value.line_total);
  if (
    unitPrice === null ||
    quantity === null ||
    quantity < 1 ||
    lineTotal === null
  ) {
    return null;
  }

  return {
    id: value.id,
    productName: value.product_name,
    variantName: asNullableString(value.variant_name),
    sku: value.sku,
    unitPrice,
    unitPriceLabel: formatMoney(unitPrice, currencyCode),
    quantity,
    lineTotal,
    lineTotalLabel: formatMoney(lineTotal, currencyCode),
  };
}

export function mapOrderHistoryRow(value: unknown): {
  id: string;
  from_status: OrderStatus | null;
  to_status: OrderStatus;
  changed_by: string | null;
  note: string | null;
  created_at: string;
} | null {
  if (!isRecord(value)) {
    return null;
  }
  if (
    typeof value.id !== "string" ||
    typeof value.to_status !== "string" ||
    typeof value.created_at !== "string" ||
    !isOrderStatus(value.to_status)
  ) {
    return null;
  }

  const fromStatus =
    value.from_status == null
      ? null
      : typeof value.from_status === "string" &&
          isOrderStatus(value.from_status)
        ? value.from_status
        : null;
  if (value.from_status != null && fromStatus === null) {
    return null;
  }

  return {
    id: value.id,
    from_status: fromStatus,
    to_status: value.to_status,
    changed_by: asNullableString(value.changed_by),
    note: asNullableString(value.note),
    created_at: value.created_at,
  };
}

export function mapShippingSnapshot(value: unknown): OrderShippingSnapshot {
  if (!isRecord(value)) {
    return emptyShippingSnapshot();
  }

  return {
    recipientName: asNullablePlainText(value.recipient_name),
    phoneNumber: asNullablePlainText(value.phone_number),
    provinceName: asNullablePlainText(value.province_name),
    districtName: asNullablePlainText(value.district_name),
    wardName: asNullablePlainText(value.ward_name),
    streetAddress: asNullablePlainText(value.street_address),
    addressNote: asNullablePlainText(value.address_note),
  };
}

export function toHistoryItem(
  row: {
    id: string;
    from_status: OrderStatus | null;
    to_status: OrderStatus;
    note: string | null;
    created_at: string;
  },
  actorName: string,
): OrderHistoryItem {
  return {
    id: row.id,
    fromStatus: row.from_status,
    fromStatusLabel: row.from_status
      ? ORDER_STATUS_LABELS[row.from_status]
      : null,
    toStatus: row.to_status,
    toStatusLabel: ORDER_STATUS_LABELS[row.to_status],
    note: row.note,
    actorName,
    createdAt: row.created_at,
    createdAtLabel: formatDateTime(row.created_at),
  };
}

export function buildOrderDetail(input: {
  order: NonNullable<ReturnType<typeof mapOrderDetailRow>>;
  items: OrderItemSnapshot[];
  history: OrderHistoryItem[];
}): OrderDetail {
  const { order, items, history } = input;
  return {
    orderId: order.id,
    orderNumber: order.order_number,
    status: order.status,
    statusLabel: ORDER_STATUS_LABELS[order.status],
    paymentMethod: order.payment_method,
    paymentStatus: order.payment_status,
    paymentStatusLabel: PAYMENT_STATUS_LABELS[order.payment_status],
    currencyCode: order.currency_code,
    subtotal: order.subtotal,
    subtotalLabel: formatMoney(order.subtotal, order.currency_code),
    discountTotal: order.discount_total,
    discountTotalLabel: formatMoney(order.discount_total, order.currency_code),
    shippingFee: order.shipping_fee,
    shippingFeeLabel: formatMoney(order.shipping_fee, order.currency_code),
    grandTotal: order.grand_total,
    grandTotalLabel: formatMoney(order.grand_total, order.currency_code),
    customerNote: order.customer_note,
    recipientName: order.recipient_name,
    recipientPhone: order.recipient_phone,
    shipping: mapShippingSnapshot(order.shipping_address),
    placedAt: order.placed_at,
    placedAtLabel: formatDateTime(order.placed_at),
    cancelledAt: order.cancelled_at,
    cancelledAtLabel: order.cancelled_at
      ? formatDateTime(order.cancelled_at)
      : null,
    nextStatuses: getNextOrderStatuses(order.status),
    items,
    history,
  };
}

function isPaymentStatus(value: string): value is PaymentStatus {
  return value in PAYMENT_STATUS_LABELS && value !== "all";
}

function emptyShippingSnapshot(): OrderShippingSnapshot {
  return {
    recipientName: null,
    phoneNumber: null,
    provinceName: null,
    districtName: null,
    wardName: null,
    streetAddress: null,
    addressNote: null,
  };
}

function formatMoney(value: number, currencyCode: string): string {
  try {
    return new Intl.NumberFormat("vi-VN", {
      style: "currency",
      currency: currencyCode,
      maximumFractionDigits: 0,
    }).format(value);
  } catch {
    return `${value} ${currencyCode}`;
  }
}

function formatDateTime(value: string): string {
  const date = new Date(value);
  if (!Number.isFinite(date.getTime())) {
    return value;
  }
  return new Intl.DateTimeFormat("en-GB", {
    dateStyle: "medium",
    timeStyle: "short",
    timeZone: "UTC",
  }).format(date);
}

function asInteger(value: unknown): number | null {
  if (typeof value === "number" && Number.isInteger(value)) {
    return value;
  }
  if (typeof value === "string" && /^-?\d+$/.test(value)) {
    const parsed = Number(value);
    return Number.isSafeInteger(parsed) ? parsed : null;
  }
  return null;
}

function asMoney(value: unknown): number | null {
  if (typeof value === "number" && Number.isFinite(value)) {
    return value;
  }
  if (typeof value === "string" && value.trim() !== "") {
    const parsed = Number(value);
    return Number.isFinite(parsed) ? parsed : null;
  }
  return null;
}

function asNullableString(value: unknown): string | null {
  if (value == null) {
    return null;
  }
  return typeof value === "string" ? value : null;
}

function asNullablePlainText(value: unknown): string | null {
  if (typeof value !== "string") {
    return null;
  }
  const trimmed = value.trim();
  if (!trimmed) {
    return null;
  }
  return trimmed.replace(/[<>]/g, "");
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null;
}
