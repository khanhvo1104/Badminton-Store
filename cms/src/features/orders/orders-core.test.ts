import { describe, expect, it } from "vitest";

import {
  getNextOrderStatuses,
  isAllowedOrderTransition,
  normalizeOrderNote,
  ordersExplorerHasActiveFilters,
  parseOrdersExplorerQuery,
} from "@/features/orders/validation";
import { sanitizeOrdersSearchLiteral } from "@/features/orders/search";
import {
  assertNoProviderLeak,
  sanitizeOrdersProviderError,
  toOrderMutationFailureMessage,
} from "@/features/orders/errors";
import {
  buildOrderDetail,
  mapCmsOrderRpcRow,
  mapOrderItemRow,
  readTransitionedOrderId,
} from "@/features/orders/mappers";
import { parseOrderTransitionFormInput } from "@/features/orders/form-validation";

describe("orders core helpers", () => {
  it("parses bounded explorer query values and drops inverted dates", () => {
    const query = parseOrdersExplorerQuery({
      q: `  BDM-1${"%".repeat(100)} `,
      status: "confirmed",
      paymentStatus: "unpaid",
      placedFrom: "2026-08-20T10:00:00.000Z",
      placedTo: "2026-08-19T10:00:00.000Z",
      sort: "total_desc",
      page: "2",
      pageSize: "10",
    });

    expect(query.search.length).toBeLessThanOrEqual(80);
    expect(query.status).toBe("confirmed");
    expect(query.paymentStatus).toBe("unpaid");
    expect(query.placedFrom).toBeNull();
    expect(query.placedTo).toBeNull();
    expect(query.sort).toBe("total_desc");
    expect(query.pagination).toEqual({
      page: 2,
      pageSize: 10,
      from: 10,
      to: 19,
    });
    expect(ordersExplorerHasActiveFilters(query)).toBe(true);
  });

  it("strips wildcard characters from search literals", () => {
    expect(sanitizeOrdersSearchLiteral("  ab%c_d\\e  ")).toBe("abcde");
  });

  it("exposes the allowed transition graph", () => {
    expect(getNextOrderStatuses("pending")).toEqual(["confirmed", "cancelled"]);
    expect(isAllowedOrderTransition("shipping", "delivered")).toBe(true);
    expect(isAllowedOrderTransition("shipping", "cancelled")).toBe(false);
    expect(getNextOrderStatuses("cancelled")).toEqual([]);
  });

  it("normalizes optional staff notes", () => {
    expect(normalizeOrderNote("  hello   world  ")).toBe("hello world");
    expect(normalizeOrderNote("   ")).toBeNull();
  });

  it("sanitizes provider errors and rejects leaks", () => {
    expect(
      sanitizeOrdersProviderError({ message: "permission denied sql" }),
    ).toBe("We couldn't load orders right now. Try again in a moment.");
    expect(toOrderMutationFailureMessage({ message: "PGRST116" })).toBe(
      "We couldn't update that order status. Check your input and try again.",
    );
    expect(
      assertNoProviderLeak(
        "We couldn't update that order status. Check your input and try again.",
      ),
    ).toBe(true);
  });

  it("fail-closes transition payloads and mapper rows", () => {
    const formData = new FormData();
    formData.set("to_status", "shipping");
    formData.set("note", "ok");
    formData.set("confirmed", "1");
    formData.set("order_id", "attacker");
    formData.set("current_status", "pending");
    formData.set("actor_id", "forged");

    const parsed = parseOrderTransitionFormInput(formData, "pending");
    expect(parsed.ok).toBe(false);

    expect(
      readTransitionedOrderId(
        [{ order_id: "40000000-0000-4000-8000-000000000001", extra: true }],
        "40000000-0000-4000-8000-000000000001",
      ),
    ).toBeNull();

    expect(
      mapCmsOrderRpcRow({
        order_id: null,
        filtered_count: 0,
      }),
    ).toMatchObject({ order_id: null, filtered_count: 0 });
  });

  it("formats line items with the order currency, not a hard-coded VND", () => {
    const item = mapOrderItemRow(
      {
        id: "50000000-0000-4000-8000-000000000001",
        product_name: "Aero",
        variant_name: "Red",
        sku: "SKU-1",
        unit_price: 12.5,
        quantity: 2,
        line_total: 25,
      },
      "USD",
    );
    expect(item).not.toBeNull();
    expect(item?.unitPriceLabel).toMatch(/US\$|USD/);
    expect(item?.unitPriceLabel).not.toMatch(/₫|VND/i);
    expect(item?.lineTotalLabel).toMatch(/US\$|USD/);
    expect(item?.lineTotalLabel).not.toMatch(/₫|VND/i);

    const vndItem = mapOrderItemRow(
      {
        id: "50000000-0000-4000-8000-000000000001",
        product_name: "Aero",
        variant_name: "Red",
        sku: "SKU-1",
        unit_price: 12.5,
        quantity: 2,
        line_total: 25,
      },
      "VND",
    );
    expect(vndItem?.unitPriceLabel).not.toBe(item?.unitPriceLabel);
    expect(vndItem?.lineTotalLabel).not.toBe(item?.lineTotalLabel);

    const detail = buildOrderDetail({
      order: {
        id: "40000000-0000-4000-8000-000000000099",
        order_number: "BDM-USD-1",
        status: "pending",
        payment_method: "cod",
        payment_status: "unpaid",
        currency_code: "USD",
        subtotal: 25,
        discount_total: 0,
        shipping_fee: 0,
        grand_total: 25,
        customer_note: null,
        recipient_name: "Pat",
        recipient_phone: "0900000000",
        shipping_address: {},
        placed_at: "2026-08-20T00:00:00.000Z",
        cancelled_at: null,
      },
      items: [item!],
      history: [],
    });

    expect(detail.grandTotalLabel).toMatch(/US\$|USD/);
    expect(detail.items[0]?.lineTotalLabel).toBe(item?.lineTotalLabel);
    expect(detail.items[0]?.unitPriceLabel).toBe(item?.unitPriceLabel);
  });
});
