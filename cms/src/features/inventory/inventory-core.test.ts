import { describe, expect, it } from "vitest";

import {
  INVENTORY_GENERIC_FAILURE_MESSAGE,
  INVENTORY_LOAD_FAILURE_MESSAGE,
  INVENTORY_PAGE_SIZE_MAX,
} from "@/features/inventory/constants";
import { assertNoProviderLeak } from "@/features/inventory/errors";
import { parseInventoryFormInput } from "@/features/inventory/form-validation";
import {
  availableQuantity,
  mapCmsInventoryRpcRow,
  mapInventoryListItem,
  mapInventoryVariantRow,
  readAdjustedInventoryVariantId,
} from "@/features/inventory/mappers";
import { sanitizeInventorySearchLiteral } from "@/features/inventory/search";
import {
  getInventoryExplorerRpcArgs,
  inventoryExplorerHasActiveFilters,
  inventoryExplorerHref,
  parseExactInteger,
  parseInventoryExplorerQuery,
} from "@/features/inventory/validation";

describe("inventory explorer query parsing", () => {
  it("clamps page size and defaults invalid sort/stock", () => {
    const query = parseInventoryExplorerQuery({
      page: "0",
      pageSize: "999",
      sort: "drop-table",
      stock: "cost_price",
      q: `  Yonex %_\\  ${"x".repeat(200)}`,
    });

    expect(query.pagination.page).toBe(1);
    expect(query.pagination.pageSize).toBe(INVENTORY_PAGE_SIZE_MAX);
    expect(query.sort).toBe("updated_desc");
    expect(query.stock).toBe("all");
    expect(query.search.length).toBeLessThanOrEqual(80);
    expect(query.search.startsWith("Yonex")).toBe(true);
  });

  it("builds bounded RPC args and hrefs", () => {
    const query = parseInventoryExplorerQuery({
      q: "INV-1",
      stock: "low_stock",
      sort: "sku_asc",
      page: "2",
      pageSize: "10",
    });
    expect(getInventoryExplorerRpcArgs(query)).toEqual({
      p_search: "INV-1",
      p_stock: "low_stock",
      p_sort: "sku_asc",
      p_offset: 10,
      p_limit: 10,
    });
    expect(inventoryExplorerHref(query)).toContain("stock=low_stock");
    expect(inventoryExplorerHasActiveFilters(query)).toBe(true);
    expect(
      inventoryExplorerHasActiveFilters(parseInventoryExplorerQuery({})),
    ).toBe(false);
  });

  it("strips wildcard characters from search literals", () => {
    expect(sanitizeInventorySearchLiteral("%Yonex_\\")).toBe("Yonex");
  });
});

describe("exact integer parsing", () => {
  it("accepts whole digits and rejects floats, signs, and overflow", () => {
    expect(parseExactInteger("0")).toBe(0);
    expect(parseExactInteger("12")).toBe(12);
    expect(parseExactInteger("2147483647")).toBe(2147483647);
    expect(parseExactInteger("01")).toBeNull();
    expect(parseExactInteger("-1")).toBeNull();
    expect(parseExactInteger("1.5")).toBeNull();
    expect(parseExactInteger("1e2")).toBeNull();
    expect(parseExactInteger("+3")).toBeNull();
    expect(parseExactInteger("2147483648")).toBeNull();
    expect(parseExactInteger(" ")).toBeNull();
  });
});

describe("inventory form parsing", () => {
  it("parses add stock and ignores a forged variant field", () => {
    const formData = new FormData();
    formData.set("operation", "add_stock");
    formData.set("quantity", "4");
    formData.set("reason", "received");
    formData.set("note", "  pallet one  ");
    formData.set("variant_id", "40000000-0000-4000-8000-000000000088");
    formData.set("allow_backorder", "");

    const parsed = parseInventoryFormInput(formData);
    expect(parsed.ok).toBe(true);
    if (!parsed.ok) {
      return;
    }
    expect(parsed.data).toEqual({
      operation: "add_stock",
      quantity: 4,
      allowBackorder: null,
      reason: "received",
      note: "pallet one",
    });
  });

  it("fail-closes unknown operations, reasons, and non-integers", () => {
    const formData = new FormData();
    formData.set("operation", "set_reserved");
    formData.set("quantity", "1.5");
    formData.set("reason", "because I said so");
    formData.set("allow_backorder", "maybe");

    const parsed = parseInventoryFormInput(formData);
    expect(parsed.ok).toBe(false);
    if (parsed.ok) {
      return;
    }
    expect(parsed.fieldErrors.operation).toBeTruthy();
    expect(parsed.fieldErrors.reason).toBeTruthy();
    expect(assertNoProviderLeak(parsed.message)).toBe(true);
  });
});

describe("inventory mappers", () => {
  it("maps list rows and rejects cost or barcode leakage", () => {
    const row = mapCmsInventoryRpcRow({
      variant_id: "40000000-0000-4000-8000-000000000001",
      product_id: "30000000-0000-4000-8000-000000000001",
      product_name: "Aero",
      variant_name: "Red",
      sku: "SKU-1",
      quantity_on_hand: 10,
      quantity_reserved: 2,
      quantity_available: 8,
      reorder_level: 4,
      allow_backorder: false,
      stock_state: "in_stock",
      updated_at: "2026-08-18T00:00:00.000Z",
      filtered_count: 1,
    });
    expect(row).not.toBeNull();
    const item = mapInventoryListItem(
      row as NonNullable<typeof row> & { variant_id: string },
    );
    expect(item?.sku).toBe("SKU-1");
    expect(item?.quantityAvailable).toBe(8);
    expect(JSON.stringify(item)).not.toMatch(/cost_price|barcode/i);
    expect(
      mapInventoryVariantRow({
        id: "40000000-0000-4000-8000-000000000001",
        product_id: "30000000-0000-4000-8000-000000000001",
        sku: "SKU-1",
        name: "Red",
        cost_price: 1,
      }),
    ).toBeNull();
    expect(availableQuantity(5, 8)).toBe(0);
  });

  it("accepts a single variant_id adjust row and rejects unsafe payloads", () => {
    const variantId = "40000000-0000-4000-8000-000000000001";
    const otherId = "40000000-0000-4000-8000-000000000088";

    expect(
      readAdjustedInventoryVariantId([{ variant_id: variantId }], variantId),
    ).toBe(variantId);
    expect(readAdjustedInventoryVariantId(variantId, variantId)).toBe(
      variantId,
    );
    expect(readAdjustedInventoryVariantId([variantId], variantId)).toBe(
      variantId,
    );

    expect(readAdjustedInventoryVariantId([], variantId)).toBeNull();
    expect(readAdjustedInventoryVariantId(null, variantId)).toBeNull();
    expect(
      readAdjustedInventoryVariantId(
        [{ variant_id: variantId }, { variant_id: variantId }],
        variantId,
      ),
    ).toBeNull();
    expect(
      readAdjustedInventoryVariantId([{ variant_id: "not-a-uuid" }], variantId),
    ).toBeNull();
    expect(
      readAdjustedInventoryVariantId([{ variant_id: otherId }], variantId),
    ).toBeNull();
    expect(
      readAdjustedInventoryVariantId(
        [{ variant_id: variantId, quantity_on_hand: 13 }],
        variantId,
      ),
    ).toBeNull();
    expect(
      readAdjustedInventoryVariantId(
        [{ variant_id: variantId, cost_price: "1" }],
        variantId,
      ),
    ).toBeNull();
    expect(
      readAdjustedInventoryVariantId(
        [{ variant_id: variantId, barcode: "x" }],
        variantId,
      ),
    ).toBeNull();
  });
});

describe("sanitized inventory errors", () => {
  it("does not leak provider internals", () => {
    expect(assertNoProviderLeak(INVENTORY_LOAD_FAILURE_MESSAGE)).toBe(true);
    expect(assertNoProviderLeak(INVENTORY_GENERIC_FAILURE_MESSAGE)).toBe(true);
  });
});
