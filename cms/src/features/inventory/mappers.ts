import {
  INVENTORY_OPERATION_LABELS,
  INVENTORY_REASON_LABELS,
  INVENTORY_STOCK_LABELS,
} from "@/features/inventory/constants";
import type {
  InventoryDetail,
  InventoryHistoryItem,
  InventoryListItem,
  InventoryOperation,
  InventoryReason,
  InventoryStockState,
} from "@/features/inventory/types";
import {
  isInventoryOperation,
  isInventoryReason,
} from "@/features/inventory/validation";
import { isValidUuid } from "@/features/products/validation";

const ADJUST_RESULT_KEYS = ["variant_id"] as const;

export type CmsInventoryRpcRow = {
  variant_id: string | null;
  product_id: string | null;
  product_name: string | null;
  variant_name: string | null;
  sku: string | null;
  quantity_on_hand: number | null;
  quantity_reserved: number | null;
  quantity_available: number | null;
  reorder_level: number | null;
  allow_backorder: boolean | null;
  stock_state: string | null;
  updated_at: string | null;
  filtered_count: number;
};

export function readAdjustedInventoryVariantId(
  data: unknown,
  expectedVariantId: string,
): string | null {
  if (!isValidUuid(expectedVariantId)) {
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
    keys.length !== ADJUST_RESULT_KEYS.length ||
    keys[0] !== "variant_id" ||
    !Object.prototype.hasOwnProperty.call(row, "variant_id")
  ) {
    return null;
  }
  if (typeof row.variant_id !== "string" || !isValidUuid(row.variant_id)) {
    return null;
  }
  if (row.variant_id !== expectedVariantId) {
    return null;
  }
  return row.variant_id;
}

export function mapCmsInventoryRpcRow(
  value: unknown,
): CmsInventoryRpcRow | null {
  if (!isRecord(value)) {
    return null;
  }

  const filteredCount = asInteger(value.filtered_count);
  if (filteredCount === null || filteredCount < 0) {
    return null;
  }

  if (value.variant_id == null) {
    return {
      variant_id: null,
      product_id: null,
      product_name: null,
      variant_name: null,
      sku: null,
      quantity_on_hand: null,
      quantity_reserved: null,
      quantity_available: null,
      reorder_level: null,
      allow_backorder: null,
      stock_state: null,
      updated_at: null,
      filtered_count: filteredCount,
    };
  }

  if (
    typeof value.variant_id !== "string" ||
    typeof value.product_id !== "string" ||
    typeof value.product_name !== "string" ||
    typeof value.sku !== "string" ||
    typeof value.stock_state !== "string" ||
    typeof value.updated_at !== "string"
  ) {
    return null;
  }

  if (value.stock_state === "missing") {
    return {
      variant_id: value.variant_id,
      product_id: value.product_id,
      product_name: value.product_name,
      variant_name: asNullableString(value.variant_name),
      sku: value.sku,
      quantity_on_hand: null,
      quantity_reserved: null,
      quantity_available: null,
      reorder_level: null,
      allow_backorder: null,
      stock_state: value.stock_state,
      updated_at: value.updated_at,
      filtered_count: filteredCount,
    };
  }

  const onHand = asInteger(value.quantity_on_hand);
  const reserved = asInteger(value.quantity_reserved);
  const available = asInteger(value.quantity_available);
  const reorder = asInteger(value.reorder_level);
  if (
    onHand === null ||
    reserved === null ||
    available === null ||
    reorder === null ||
    typeof value.allow_backorder !== "boolean"
  ) {
    return null;
  }

  return {
    variant_id: value.variant_id,
    product_id: value.product_id,
    product_name: value.product_name,
    variant_name: asNullableString(value.variant_name),
    sku: value.sku,
    quantity_on_hand: onHand,
    quantity_reserved: reserved,
    quantity_available: available,
    reorder_level: reorder,
    allow_backorder: value.allow_backorder,
    stock_state: value.stock_state,
    updated_at: value.updated_at,
    filtered_count: filteredCount,
  };
}

export function mapInventoryListItem(
  row: CmsInventoryRpcRow & { variant_id: string },
): InventoryListItem | null {
  const stockState = asStockState(row.stock_state);
  if (!stockState || !row.product_id || !row.product_name || !row.sku) {
    return null;
  }

  return {
    variantId: row.variant_id,
    productId: row.product_id,
    productName: row.product_name,
    variantName: row.variant_name,
    sku: row.sku,
    quantityOnHand: row.quantity_on_hand,
    quantityReserved: row.quantity_reserved,
    quantityAvailable: row.quantity_available,
    reorderLevel: row.reorder_level,
    allowBackorder: row.allow_backorder,
    allowBackorderLabel: booleanLabel(row.allow_backorder),
    stockState,
    stockLabel: INVENTORY_STOCK_LABELS[stockState],
    updatedAt: row.updated_at ?? "",
    updatedAtLabel: formatTimestamp(row.updated_at),
  };
}

export function mapInventoryVariantRow(value: unknown): {
  id: string;
  product_id: string;
  sku: string;
  name: string | null;
} | null {
  if (!isRecord(value)) {
    return null;
  }
  if (
    typeof value.id !== "string" ||
    typeof value.product_id !== "string" ||
    typeof value.sku !== "string"
  ) {
    return null;
  }
  if ("cost_price" in value || "barcode" in value) {
    return null;
  }
  return {
    id: value.id,
    product_id: value.product_id,
    sku: value.sku,
    name: asNullableString(value.name),
  };
}

export function mapInventoryProductRow(value: unknown): {
  id: string;
  name: string;
} | null {
  if (!isRecord(value)) {
    return null;
  }
  if (typeof value.id !== "string" || typeof value.name !== "string") {
    return null;
  }
  return { id: value.id, name: value.name };
}

export function mapInventoryRow(value: unknown): {
  variant_id: string;
  quantity_on_hand: number;
  quantity_reserved: number;
  reorder_level: number;
  allow_backorder: boolean;
  updated_at: string;
} | null {
  if (!isRecord(value)) {
    return null;
  }
  const onHand = asInteger(value.quantity_on_hand);
  const reserved = asInteger(value.quantity_reserved);
  const reorder = asInteger(value.reorder_level);
  if (
    typeof value.variant_id !== "string" ||
    onHand === null ||
    reserved === null ||
    reorder === null ||
    typeof value.allow_backorder !== "boolean" ||
    typeof value.updated_at !== "string"
  ) {
    return null;
  }
  return {
    variant_id: value.variant_id,
    quantity_on_hand: onHand,
    quantity_reserved: reserved,
    reorder_level: reorder,
    allow_backorder: value.allow_backorder,
    updated_at: value.updated_at,
  };
}

export function mapInventoryHistoryRow(value: unknown): {
  id: string;
  variant_id: string;
  actor_id: string;
  operation: InventoryOperation;
  reason: InventoryReason;
  note: string | null;
  quantity_on_hand_before: number;
  quantity_on_hand_after: number;
  quantity_reserved_before: number;
  quantity_reserved_after: number;
  reorder_level_before: number;
  reorder_level_after: number;
  allow_backorder_before: boolean;
  allow_backorder_after: boolean;
  created_at: string;
} | null {
  if (!isRecord(value)) {
    return null;
  }
  const operation =
    typeof value.operation === "string" && isInventoryOperation(value.operation)
      ? value.operation
      : null;
  const reason =
    typeof value.reason === "string" && isInventoryReason(value.reason)
      ? value.reason
      : null;
  const onHandBefore = asInteger(value.quantity_on_hand_before);
  const onHandAfter = asInteger(value.quantity_on_hand_after);
  const reservedBefore = asInteger(value.quantity_reserved_before);
  const reservedAfter = asInteger(value.quantity_reserved_after);
  const reorderBefore = asInteger(value.reorder_level_before);
  const reorderAfter = asInteger(value.reorder_level_after);
  if (
    typeof value.id !== "string" ||
    typeof value.variant_id !== "string" ||
    typeof value.actor_id !== "string" ||
    !operation ||
    !reason ||
    onHandBefore === null ||
    onHandAfter === null ||
    reservedBefore === null ||
    reservedAfter === null ||
    reservedBefore !== reservedAfter ||
    reorderBefore === null ||
    reorderAfter === null ||
    typeof value.allow_backorder_before !== "boolean" ||
    typeof value.allow_backorder_after !== "boolean" ||
    typeof value.created_at !== "string"
  ) {
    return null;
  }

  return {
    id: value.id,
    variant_id: value.variant_id,
    actor_id: value.actor_id,
    operation,
    reason,
    note: asNullableString(value.note),
    quantity_on_hand_before: onHandBefore,
    quantity_on_hand_after: onHandAfter,
    quantity_reserved_before: reservedBefore,
    quantity_reserved_after: reservedAfter,
    reorder_level_before: reorderBefore,
    reorder_level_after: reorderAfter,
    allow_backorder_before: value.allow_backorder_before,
    allow_backorder_after: value.allow_backorder_after,
    created_at: value.created_at,
  };
}

export function toHistoryItem(
  row: NonNullable<ReturnType<typeof mapInventoryHistoryRow>>,
  actorName: string,
): InventoryHistoryItem {
  return {
    id: row.id,
    operation: row.operation,
    operationLabel: INVENTORY_OPERATION_LABELS[row.operation],
    reason: row.reason,
    reasonLabel: INVENTORY_REASON_LABELS[row.reason],
    note: row.note,
    quantityOnHandBefore: row.quantity_on_hand_before,
    quantityOnHandAfter: row.quantity_on_hand_after,
    quantityReserved: row.quantity_reserved_after,
    reorderLevelBefore: row.reorder_level_before,
    reorderLevelAfter: row.reorder_level_after,
    allowBackorderBefore: row.allow_backorder_before,
    allowBackorderAfter: row.allow_backorder_after,
    actorName,
    createdAt: row.created_at,
    createdAtLabel: formatTimestamp(row.created_at),
  };
}

export function buildInventoryDetail(options: {
  variantId: string;
  productId: string;
  productName: string;
  variantName: string | null;
  sku: string;
  inventory: ReturnType<typeof mapInventoryRow>;
  history: InventoryHistoryItem[];
}): InventoryDetail {
  const { inventory } = options;
  if (!inventory) {
    return {
      variantId: options.variantId,
      productId: options.productId,
      productName: options.productName,
      variantName: options.variantName,
      sku: options.sku,
      quantityOnHand: null,
      quantityReserved: null,
      quantityAvailable: null,
      reorderLevel: null,
      allowBackorder: null,
      allowBackorderLabel: booleanLabel(null),
      stockState: "missing",
      stockLabel: INVENTORY_STOCK_LABELS.missing,
      updatedAt: null,
      updatedAtLabel: "No inventory row",
      hasInventoryRow: false,
      history: options.history,
    };
  }

  const available = availableQuantity(
    inventory.quantity_on_hand,
    inventory.quantity_reserved,
  );
  const stockState = resolveStockState(available, inventory.reorder_level);

  return {
    variantId: options.variantId,
    productId: options.productId,
    productName: options.productName,
    variantName: options.variantName,
    sku: options.sku,
    quantityOnHand: inventory.quantity_on_hand,
    quantityReserved: inventory.quantity_reserved,
    quantityAvailable: available,
    reorderLevel: inventory.reorder_level,
    allowBackorder: inventory.allow_backorder,
    allowBackorderLabel: booleanLabel(inventory.allow_backorder),
    stockState,
    stockLabel: INVENTORY_STOCK_LABELS[stockState],
    updatedAt: inventory.updated_at,
    updatedAtLabel: formatTimestamp(inventory.updated_at),
    hasInventoryRow: true,
    history: options.history,
  };
}

export function availableQuantity(onHand: number, reserved: number): number {
  const remaining = onHand - reserved;
  return remaining > 0 ? remaining : 0;
}

export function formatTimestamp(value: string | null): string {
  if (!value) {
    return "Unknown";
  }

  return new Intl.DateTimeFormat("en-GB", {
    dateStyle: "medium",
    timeStyle: "short",
    timeZone: "UTC",
  }).format(new Date(value));
}

export function booleanLabel(value: boolean | null): string {
  if (value === null) {
    return "Unknown";
  }
  return value ? "Yes" : "No";
}

function resolveStockState(
  available: number,
  reorderLevel: number,
): Exclude<InventoryStockState, "all"> {
  if (available === 0) {
    return "out_of_stock";
  }
  if (available <= reorderLevel) {
    return "low_stock";
  }
  return "in_stock";
}

function asStockState(
  value: string | null,
): Exclude<InventoryStockState, "all"> | null {
  if (
    value === "in_stock" ||
    value === "low_stock" ||
    value === "out_of_stock" ||
    value === "missing"
  ) {
    return value;
  }
  return null;
}

function asInteger(value: unknown): number | null {
  if (typeof value === "number" && Number.isInteger(value)) {
    return value;
  }
  if (typeof value === "string" && /^-?\d+$/.test(value)) {
    const parsed = Number(value);
    return Number.isInteger(parsed) ? parsed : null;
  }
  return null;
}

function asNullableString(value: unknown): string | null {
  if (value == null) {
    return null;
  }
  return typeof value === "string" ? value : null;
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null;
}
