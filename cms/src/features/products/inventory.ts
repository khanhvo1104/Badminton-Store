import {
  PRODUCT_NO_INVENTORY_LABEL,
  PRODUCT_STOCK_LABELS,
} from "@/features/products/constants";
import type {
  ProductInventorySummary,
  ProductStockState,
} from "@/features/products/types";

export type InventoryAggregateInput = {
  variantCount: number;
  rows: Array<{
    quantityOnHand: number;
    quantityReserved: number;
    reorderLevel: number;
  }>;
};

export function availableQuantity(onHand: number, reserved: number): number {
  const remaining = onHand - reserved;
  return remaining > 0 ? remaining : 0;
}

export function aggregateInventory(
  input: InventoryAggregateInput,
): ProductInventorySummary | null {
  const { variantCount, rows } = input;

  if (rows.length > variantCount) {
    return null;
  }

  const missingInventoryCount = variantCount - rows.length;
  const hasMissingInventory = missingInventoryCount > 0;

  if (rows.length === 0) {
    return {
      totalOnHand: null,
      totalReserved: null,
      totalAvailable: null,
      missingInventoryCount,
      hasMissingInventory: variantCount > 0,
      isLowStock: false,
      stockState: variantCount > 0 ? "missing" : "out_of_stock",
      stockLabel:
        variantCount > 0
          ? PRODUCT_NO_INVENTORY_LABEL
          : PRODUCT_STOCK_LABELS.out_of_stock,
    };
  }

  let totalOnHand = 0;
  let totalReserved = 0;
  let totalAvailable = 0;
  let isLowStock = false;

  for (const row of rows) {
    const available = availableQuantity(
      row.quantityOnHand,
      row.quantityReserved,
    );
    totalOnHand += row.quantityOnHand;
    totalReserved += row.quantityReserved;
    totalAvailable += available;
    if (available <= row.reorderLevel) {
      isLowStock = true;
    }
  }

  const stockState = resolveStockState({
    hasMissingInventory,
    isLowStock,
    totalAvailable,
  });

  return {
    totalOnHand,
    totalReserved,
    totalAvailable,
    missingInventoryCount,
    hasMissingInventory,
    isLowStock,
    stockState,
    stockLabel: hasMissingInventory
      ? PRODUCT_NO_INVENTORY_LABEL
      : PRODUCT_STOCK_LABELS[stockState],
  };
}

export function productMatchesStockFilter(
  summary: ProductInventorySummary,
  stock: ProductStockState,
): boolean {
  if (stock === "all") {
    return true;
  }
  if (stock === "missing") {
    return summary.hasMissingInventory;
  }
  if (stock === "low_stock") {
    return summary.isLowStock;
  }
  if (stock === "in_stock") {
    return (summary.totalAvailable ?? 0) > 0;
  }
  return summary.stockState === "out_of_stock";
}

function resolveStockState(options: {
  hasMissingInventory: boolean;
  isLowStock: boolean;
  totalAvailable: number;
}): Exclude<ProductStockState, "all"> {
  if (options.hasMissingInventory) {
    return "missing";
  }
  if (options.totalAvailable === 0) {
    return "out_of_stock";
  }
  if (options.isLowStock) {
    return "low_stock";
  }
  return "in_stock";
}
