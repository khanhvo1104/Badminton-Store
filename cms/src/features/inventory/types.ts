import type {
  INVENTORY_OPERATIONS,
  INVENTORY_REASONS,
  INVENTORY_SORTS,
  INVENTORY_STOCK_STATES,
} from "@/features/inventory/constants";

export type InventoryStockState = (typeof INVENTORY_STOCK_STATES)[number];
export type InventorySort = (typeof INVENTORY_SORTS)[number];
export type InventoryOperation = (typeof INVENTORY_OPERATIONS)[number];
export type InventoryReason = (typeof INVENTORY_REASONS)[number];

export type InventoryPagination = {
  page: number;
  pageSize: number;
  from: number;
  to: number;
};

export type InventoryExplorerQuery = {
  search: string;
  stock: InventoryStockState;
  sort: InventorySort;
  pagination: InventoryPagination;
};

export type InventoryListItem = {
  variantId: string;
  productId: string;
  productName: string;
  variantName: string | null;
  sku: string;
  quantityOnHand: number | null;
  quantityReserved: number | null;
  quantityAvailable: number | null;
  reorderLevel: number | null;
  allowBackorder: boolean | null;
  allowBackorderLabel: string;
  stockState: Exclude<InventoryStockState, "all">;
  stockLabel: string;
  updatedAt: string;
  updatedAtLabel: string;
};

export type InventoryListResult = {
  items: InventoryListItem[];
  totalCount: number;
  pagination: InventoryPagination;
  totalPages: number;
  query: InventoryExplorerQuery;
  hasActiveFilters: boolean;
};

export type InventoryExplorerLoadResult =
  | { ok: true; result: InventoryListResult }
  | { ok: false; message: string };

export type InventoryHistoryItem = {
  id: string;
  operation: InventoryOperation;
  operationLabel: string;
  reason: InventoryReason;
  reasonLabel: string;
  note: string | null;
  quantityOnHandBefore: number;
  quantityOnHandAfter: number;
  quantityReserved: number;
  reorderLevelBefore: number;
  reorderLevelAfter: number;
  allowBackorderBefore: boolean;
  allowBackorderAfter: boolean;
  actorName: string;
  createdAt: string;
  createdAtLabel: string;
};

export type InventoryDetail = {
  variantId: string;
  productId: string;
  productName: string;
  variantName: string | null;
  sku: string;
  quantityOnHand: number | null;
  quantityReserved: number | null;
  quantityAvailable: number | null;
  reorderLevel: number | null;
  allowBackorder: boolean | null;
  allowBackorderLabel: string;
  stockState: Exclude<InventoryStockState, "all">;
  stockLabel: string;
  updatedAt: string | null;
  updatedAtLabel: string;
  hasInventoryRow: boolean;
  history: InventoryHistoryItem[];
};

export type InventoryDetailLoadResult =
  | { ok: true; detail: InventoryDetail }
  | { ok: false; message: string; notFound?: boolean };

export type InventoryFormValues = {
  operation: string;
  quantity: string;
  allowBackorder: string;
  reason: string;
  note: string;
};

export type InventoryFieldErrors = {
  operation?: string;
  quantity?: string;
  allowBackorder?: string;
  reason?: string;
  note?: string;
};

export type InventoryFormState = {
  status: "idle" | "error";
  message: string | null;
  fieldErrors: InventoryFieldErrors;
  values: InventoryFormValues;
};

export type ParsedInventoryAdjustment = {
  operation: InventoryOperation;
  quantity: number | null;
  allowBackorder: boolean | null;
  reason: InventoryReason;
  note: string | null;
};
