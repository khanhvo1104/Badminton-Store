import { describe, expect, it } from "vitest";

import {
  formatVariantAttributesForForm,
  parseVariantAttributesInput,
} from "@/features/variants/attributes";
import {
  VARIANT_ATTRIBUTES_INVALID_MESSAGE,
  VARIANT_BOOLEAN_INVALID_MESSAGE,
  VARIANT_COMPARE_RULE_MESSAGE,
  VARIANT_DEFAULT_LOCKED_MESSAGE,
  VARIANT_SKU_CONFLICT_MESSAGE,
  normalizeVariantSku,
} from "@/features/variants/constants";
import {
  assertNoProviderLeak,
  toVariantMutationFailureMessage,
} from "@/features/variants/errors";
import {
  buildVariantMutationArgs,
  parseVariantFormInput,
  validateVariantFormValues,
} from "@/features/variants/form-validation";
import {
  mapVariantCostRow,
  mapVariantSafeRow,
  readSavedVariantId,
} from "@/features/variants/mappers";
import { parseVariantMoney } from "@/features/variants/money";
import { mergeVariantCosts } from "@/features/variants/queries";
import { getVariantRevalidationPaths } from "@/features/variants/revalidate";
import { EMPTY_VARIANT_FORM_VALUES } from "@/features/variants/variant-form-state";

const PRODUCT_ID = "30000000-0000-4000-8000-000000000001";
const VARIANT_ID = "40000000-0000-4000-8000-000000000001";
const OTHER_VARIANT_ID = "40000000-0000-4000-8000-000000000002";

function formDataFrom(entries: Record<string, string>): FormData {
  const data = new FormData();
  for (const [key, value] of Object.entries(entries)) {
    data.set(key, value);
  }
  return data;
}

function validEntries(
  overrides: Record<string, string> = {},
): Record<string, string> {
  return {
    sku: "RKT-YON-AS88-RED-3U-G5",
    name: "3U / G5",
    color_name: "Red",
    color_hex: "#C62828",
    racket_weight_class: "3U",
    grip_size: "G5",
    shoe_size: "",
    clothing_size: "",
    unit: "item",
    price: "1890000.00",
    compare_at_price: "2190000.00",
    cost_price: "1200000.00",
    barcode: "",
    attributes: "",
    is_default: "true",
    is_active: "true",
    sort_order: "1",
    ...overrides,
  };
}

describe("variant SKU and money", () => {
  it("normalizes SKUs by trimming and collapsing whitespace without changing case", () => {
    expect(normalizeVariantSku("  RKT  YON  ")).toBe("RKT YON");
    expect(normalizeVariantSku("sku-Mixed")).toBe("sku-Mixed");
  });

  it("parses exact decimal money and rejects floats with too many places", () => {
    expect(parseVariantMoney("0")).toBe("0");
    expect(parseVariantMoney("0.00")).toBe("0.00");
    expect(parseVariantMoney("12.50")).toBe("12.50");
    expect(parseVariantMoney(12)).toBe("12");
    expect(parseVariantMoney("12.345")).toBeNull();
    expect(parseVariantMoney("1000000000000")).toBeNull();
    expect(parseVariantMoney("-1")).toBeNull();
  });
});

describe("variant form validation", () => {
  it("accepts a complete create payload and allowlists mutation args", () => {
    const parsed = parseVariantFormInput(formDataFrom(validEntries()), {
      mode: "create",
    });
    expect(parsed.ok).toBe(true);
    if (!parsed.ok) {
      return;
    }
    expect(parsed.data.price).toBe("1890000.00");
    expect(parsed.data.compareAtPrice).toBe("2190000.00");
    expect(parsed.data.costMode).toBe("set");
    expect(parsed.data.costPrice).toBe("1200000.00");
    expect(parsed.data.barcodeMode).toBe("unchanged");

    const args = buildVariantMutationArgs({
      productId: PRODUCT_ID,
      variantId: null,
      data: parsed.data,
    });
    expect(Object.keys(args).sort()).toEqual(
      [
        "p_attributes",
        "p_barcode",
        "p_barcode_mode",
        "p_clothing_size",
        "p_color_hex",
        "p_color_name",
        "p_compare_at_price",
        "p_cost_mode",
        "p_cost_price",
        "p_grip_size",
        "p_is_active",
        "p_is_default",
        "p_name",
        "p_price",
        "p_product_id",
        "p_racket_weight_class",
        "p_shoe_size",
        "p_sku",
        "p_sort_order",
        "p_unit",
        "p_variant_id",
      ].sort(),
    );
    expect(args.p_product_id).toBe(PRODUCT_ID);
    expect(args.p_variant_id).toBeNull();
  });

  it("ignores forged identity fields in FormData", () => {
    const data = formDataFrom(validEntries());
    data.set("product_id", "30000000-0000-4000-8000-000000000099");
    data.set("variant_id", "40000000-0000-4000-8000-000000000099");
    data.set("id", "forged");
    const parsed = parseVariantFormInput(data, { mode: "edit" });
    expect(parsed.ok).toBe(true);
    if (!parsed.ok) {
      return;
    }
    const args = buildVariantMutationArgs({
      productId: PRODUCT_ID,
      variantId: VARIANT_ID,
      data: parsed.data,
    });
    expect(args.p_product_id).toBe(PRODUCT_ID);
    expect(args.p_variant_id).toBe(VARIANT_ID);
  });

  it("rejects missing and unknown booleans instead of defaulting", () => {
    const missing = parseVariantFormInput(
      formDataFrom(
        validEntries({
          is_default: "",
          is_active: "",
        }),
      ),
      { mode: "create" },
    );
    expect(missing.ok).toBe(false);
    if (!missing.ok) {
      expect(missing.fieldErrors.isDefault).toBe(
        VARIANT_BOOLEAN_INVALID_MESSAGE,
      );
      expect(missing.fieldErrors.isActive).toBe(
        VARIANT_BOOLEAN_INVALID_MESSAGE,
      );
    }

    const unknown = parseVariantFormInput(
      formDataFrom(validEntries({ is_default: "yes", is_active: "1" })),
      { mode: "create" },
    );
    expect(unknown.ok).toBe(false);
    if (!unknown.ok) {
      expect(unknown.fieldErrors.isDefault).toBe(
        VARIANT_BOOLEAN_INVALID_MESSAGE,
      );
      expect(unknown.fieldErrors.isActive).toBe(
        VARIANT_BOOLEAN_INVALID_MESSAGE,
      );
    }
  });

  it("enforces compare-at >= price with exact decimal strings", () => {
    const parsed = parseVariantFormInput(
      formDataFrom(
        validEntries({
          price: "10.50",
          compare_at_price: "10.49",
        }),
      ),
      { mode: "create" },
    );
    expect(parsed.ok).toBe(false);
    if (!parsed.ok) {
      expect(parsed.fieldErrors.compareAtPrice).toBe(
        VARIANT_COMPARE_RULE_MESSAGE,
      );
      expect(parsed.values.price).toBe("10.50");
      expect(parsed.values.compareAtPrice).toBe("10.49");
    }
  });

  it("distinguishes cost null, zero, clear, and set", () => {
    const empty = validateVariantFormValues(
      {
        ...EMPTY_VARIANT_FORM_VALUES,
        sku: "SKU-1",
        price: "10",
        isDefault: "false",
        isActive: "true",
        sortOrder: "0",
      },
      { mode: "edit" },
    );
    expect(empty.ok).toBe(true);
    if (empty.ok) {
      expect(empty.data.costMode).toBe("clear");
      expect(empty.data.costPrice).toBeNull();
    }

    const zero = validateVariantFormValues(
      {
        ...EMPTY_VARIANT_FORM_VALUES,
        sku: "SKU-1",
        price: "10",
        costPrice: "0.00",
        isDefault: "false",
        isActive: "true",
        sortOrder: "0",
      },
      { mode: "edit" },
    );
    expect(zero.ok).toBe(true);
    if (zero.ok) {
      expect(zero.data.costMode).toBe("set");
      expect(zero.data.costPrice).toBe("0.00");
    }

    const preserved = validateVariantFormValues(
      {
        ...EMPTY_VARIANT_FORM_VALUES,
        sku: "SKU-1",
        price: "10",
        costPrice: "5.00",
        isDefault: "false",
        isActive: "true",
        sortOrder: "0",
      },
      { mode: "edit" },
    );
    expect(preserved.ok).toBe(true);
    if (preserved.ok) {
      expect(preserved.data.costMode).toBe("set");
      expect(preserved.data.costPrice).toBe("5.00");
    }
  });

  it("preserves barcode on edit unless a value or clear intent is supplied", () => {
    const preserved = parseVariantFormInput(formDataFrom(validEntries()), {
      mode: "edit",
    });
    expect(preserved.ok).toBe(true);
    if (preserved.ok) {
      expect(preserved.data.barcodeMode).toBe("unchanged");
      expect(preserved.data.barcode).toBeNull();
    }

    const set = parseVariantFormInput(
      formDataFrom(validEntries({ barcode: "ABC-123" })),
      { mode: "edit" },
    );
    expect(set.ok).toBe(true);
    if (set.ok) {
      expect(set.data.barcodeMode).toBe("set");
      expect(set.data.barcode).toBe("ABC-123");
    }

    const clear = formDataFrom(validEntries());
    clear.set("barcode_clear", "true");
    const cleared = parseVariantFormInput(clear, { mode: "edit" });
    expect(cleared.ok).toBe(true);
    if (cleared.ok) {
      expect(cleared.data.barcodeMode).toBe("clear");
    }
  });

  it("rejects unsetting the current default", () => {
    const parsed = parseVariantFormInput(
      formDataFrom(validEntries({ is_default: "false" })),
      { mode: "edit", currentIsDefault: true },
    );
    expect(parsed.ok).toBe(false);
    if (!parsed.ok) {
      expect(parsed.fieldErrors.isDefault).toBe(VARIANT_DEFAULT_LOCKED_MESSAGE);
    }
  });

  it("turns blank sports attributes into null", () => {
    const parsed = parseVariantFormInput(
      formDataFrom(
        validEntries({
          racket_weight_class: "  ",
          grip_size: "",
          shoe_size: "42",
        }),
      ),
      { mode: "create" },
    );
    expect(parsed.ok).toBe(true);
    if (parsed.ok) {
      expect(parsed.data.racketWeightClass).toBeNull();
      expect(parsed.data.gripSize).toBeNull();
      expect(parsed.data.shoeSize).toBe("42");
    }
  });
});

describe("variant attributes JSON", () => {
  it("rejects arrays, prototype keys, depth, and oversized payloads", () => {
    expect(parseVariantAttributesInput("[]").ok).toBe(false);
    expect(parseVariantAttributesInput('{"__proto__": {"x": 1}}').ok).toBe(
      false,
    );
    expect(parseVariantAttributesInput('{"constructor": 1}').ok).toBe(false);
    expect(
      parseVariantAttributesInput('{"a": {"b": {"c": {"d": 1}}}}').ok,
    ).toBe(false);
    const arrayResult = parseVariantAttributesInput("[1,2]");
    expect(arrayResult.ok).toBe(false);
    if (!arrayResult.ok) {
      expect(arrayResult.message).toBe(VARIANT_ATTRIBUTES_INVALID_MESSAGE);
    }
    const nestedOk = parseVariantAttributesInput('{"a": {"b": {"c": 1}}}');
    expect(nestedOk.ok).toBe(true);
    expect(formatVariantAttributesForForm({ color: "red" })).toContain("color");
  });
});

describe("variant list merge", () => {
  const baseRow = {
    id: VARIANT_ID,
    product_id: PRODUCT_ID,
    sku: "SKU-1",
    name: null,
    color_name: null,
    color_hex: null,
    racket_weight_class: null,
    grip_size: null,
    shoe_size: null,
    clothing_size: null,
    unit: "item",
    price: "10.00",
    compare_at_price: null,
    attributes: {},
    is_default: true,
    is_active: true,
    sort_order: 0,
  };

  it("merges costs by id and keeps null distinct from zero", () => {
    const row = mapVariantSafeRow(baseRow);
    expect(row).not.toBeNull();
    const merged = mergeVariantCosts(
      [row],
      [{ variant_id: VARIANT_ID, cost_price: null }],
    );
    expect(merged.ok).toBe(true);
    if (merged.ok) {
      expect(merged.items[0]?.costPrice).toBeNull();
      expect(merged.items[0]?.costPriceLabel).toBe("Not recorded");
    }

    const zero = mergeVariantCosts(
      [row],
      [{ variant_id: VARIANT_ID, cost_price: "0.00" }],
    );
    expect(zero.ok).toBe(true);
    if (zero.ok) {
      expect(zero.items[0]?.costPrice).toBe("0.00");
    }
  });

  it("fails closed on missing, duplicate, extra, or malformed cost rows", () => {
    const row = mapVariantSafeRow(baseRow);
    expect(mergeVariantCosts([row], []).ok).toBe(false);
    expect(
      mergeVariantCosts(
        [row],
        [
          { variant_id: VARIANT_ID, cost_price: null },
          { variant_id: VARIANT_ID, cost_price: "1" },
        ],
      ).ok,
    ).toBe(false);
    expect(
      mergeVariantCosts(
        [row],
        [
          { variant_id: VARIANT_ID, cost_price: null },
          { variant_id: OTHER_VARIANT_ID, cost_price: null },
        ],
      ).ok,
    ).toBe(false);
    expect(mapVariantSafeRow({ ...baseRow, cost_price: "1" })).toBeNull();
    expect(mapVariantCostRow({ variant_id: VARIANT_ID })).toBeNull();
    expect(
      mapVariantCostRow({
        variant_id: VARIANT_ID,
        cost_price: null,
        barcode: "x",
      }),
    ).toBeNull();
  });

  it("rejects save results that include protected columns", () => {
    expect(readSavedVariantId([{ variant_id: VARIANT_ID }])).toBe(VARIANT_ID);
    expect(
      readSavedVariantId([{ variant_id: VARIANT_ID, cost_price: "1" }]),
    ).toBeNull();
    expect(readSavedVariantId([])).toBeNull();
  });
});

describe("variant errors and paths", () => {
  it("sanitizes duplicate SKU conflicts", () => {
    const message = toVariantMutationFailureMessage({
      code: "23505",
      message:
        'duplicate key value violates unique constraint "product_variants_sku_unique"',
    });
    expect(message).toBe(VARIANT_SKU_CONFLICT_MESSAGE);
    expect(assertNoProviderLeak(message)).toBe(true);
  });

  it("revalidates product and variant paths", () => {
    expect(getVariantRevalidationPaths(PRODUCT_ID, VARIANT_ID)).toEqual([
      "/dashboard/products",
      `/dashboard/products/${PRODUCT_ID}`,
      `/dashboard/products/${PRODUCT_ID}/edit`,
      `/dashboard/products/${PRODUCT_ID}/variants`,
      `/dashboard/products/${PRODUCT_ID}/variants/new`,
      `/dashboard/products/${PRODUCT_ID}/variants/${VARIANT_ID}/edit`,
    ]);
  });
});
