import { describe, expect, it } from "vitest";

import {
  MEDIA_GENERIC_FAILURE_MESSAGE,
  MEDIA_IMAGE_INVALID_MESSAGE,
  PRODUCT_IMAGE_MAX_BYTES,
} from "@/features/media/constants";
import { assertNoProviderLeak } from "@/features/media/errors";
import {
  buildProductImageObjectPath,
  buildProductImagePublicUrl,
  isSafeProductImagePreviewPath,
  toStoredProductImagePath,
  validateProductImageFile,
} from "@/features/media/image";
import {
  mapProductImageRow,
  readPrimaryImageId,
  readReorderedProductId,
  readReturnedImageId,
  toProductMediaImage,
} from "@/features/media/mappers";
import {
  parseOptionalAltText,
  parseReorderImageIds,
} from "@/features/media/validation";

const PRODUCT_ID = "30000000-0000-4000-8000-000000000001";
const IMAGE_ID = "50000000-0000-4000-8000-000000000001";

describe("product media image paths", () => {
  it("builds collision-resistant product-scoped object paths", () => {
    const path = buildProductImageObjectPath(PRODUCT_ID, ".png", () => "abc");
    expect(path).toBe(`${PRODUCT_ID}/abc.png`);
    expect(toStoredProductImagePath(path)).toBe(
      `product-images/${PRODUCT_ID}/abc.png`,
    );
  });

  it("rejects SVG and traversal when building public preview URLs", () => {
    expect(
      isSafeProductImagePreviewPath(
        PRODUCT_ID,
        `product-images/${PRODUCT_ID}/../evil.svg`,
      ),
    ).toBe(false);
    expect(
      buildProductImagePublicUrl(
        "https://example.supabase.co",
        PRODUCT_ID,
        `product-images/${PRODUCT_ID}/main.svg`,
      ),
    ).toBeNull();
    expect(
      buildProductImagePublicUrl(
        "https://example.supabase.co",
        PRODUCT_ID,
        `product-images/${PRODUCT_ID}/main.webp`,
      ),
    ).toBe(
      `https://example.supabase.co/storage/v1/object/public/product-images/${PRODUCT_ID}/main.webp`,
    );
  });

  it("rejects SVG, empty, and oversize uploads", () => {
    expect(
      validateProductImageFile(
        new File(["<svg></svg>"], "logo.svg", { type: "image/svg+xml" }),
      ).ok,
    ).toBe(false);
    expect(
      validateProductImageFile(new File([], "", { type: "image/png" })),
    ).toEqual({ ok: true, image: null });
    const oversize = new File(
      [new Uint8Array(PRODUCT_IMAGE_MAX_BYTES + 1)],
      "big.png",
      { type: "image/png" },
    );
    expect(validateProductImageFile(oversize)).toEqual({
      ok: false,
      message: MEDIA_IMAGE_INVALID_MESSAGE,
    });
    const valid = validateProductImageFile(
      new File([new Uint8Array([1, 2, 3])], "shot.webp", {
        type: "image/webp",
      }),
    );
    expect(valid.ok).toBe(true);
  });
});

describe("product media mapping contracts", () => {
  it("maps stored paths to previews and rejects extra protected fields", () => {
    const row = mapProductImageRow({
      id: IMAGE_ID,
      product_id: PRODUCT_ID,
      variant_id: null,
      storage_path: `product-images/${PRODUCT_ID}/main.webp`,
      alt_text: "Main",
      sort_order: 0,
      is_primary: true,
      updated_at: "2026-08-19T00:00:00.000Z",
    });
    expect(row).not.toBeNull();
    const mapped = toProductMediaImage({
      row: row!,
      supabaseUrl: "https://example.supabase.co",
      variantLabelById: new Map(),
    });
    expect(mapped.previewUrl).not.toContain("<svg");
    expect(mapped.primaryLabel).toBe("Primary");
    expect(
      mapProductImageRow({
        id: IMAGE_ID,
        product_id: PRODUCT_ID,
        variant_id: null,
        storage_path: `product-images/${PRODUCT_ID}/main.webp`,
        alt_text: "Main",
        sort_order: 0,
        is_primary: true,
        updated_at: "2026-08-19T00:00:00.000Z",
        cost_price: "1",
      }),
    ).toBeNull();
  });

  it("fail-closes RPC payloads that include extra or protected fields", () => {
    expect(readPrimaryImageId([{ image_id: IMAGE_ID }], IMAGE_ID)).toBe(
      IMAGE_ID,
    );
    expect(
      readPrimaryImageId([{ image_id: IMAGE_ID, cost_price: "1" }], IMAGE_ID),
    ).toBeNull();
    expect(readPrimaryImageId(IMAGE_ID, IMAGE_ID)).toBeNull();
    expect(readReturnedImageId([{ image_id: IMAGE_ID }])).toBe(IMAGE_ID);
    expect(
      readReturnedImageId([{ image_id: IMAGE_ID, cost_price: "1" }]),
    ).toBeNull();
    expect(
      readReorderedProductId([{ product_id: PRODUCT_ID }], PRODUCT_ID),
    ).toBe(PRODUCT_ID);
    expect(
      readReorderedProductId(
        [{ product_id: PRODUCT_ID, barcode: "x" }],
        PRODUCT_ID,
      ),
    ).toBeNull();
  });

  it("sanitizes provider errors and bounds alt text and reorder ids", () => {
    expect(assertNoProviderLeak(MEDIA_GENERIC_FAILURE_MESSAGE)).toBe(true);
    expect(parseOptionalAltText("  Hello   world  ")).toEqual({
      ok: true,
      value: "Hello world",
    });
    expect(parseOptionalAltText("x".repeat(201)).ok).toBe(false);
    const formData = new FormData();
    formData.append("image_ids", IMAGE_ID);
    formData.append("image_ids", "not-a-uuid");
    expect(parseReorderImageIds(formData, 2).ok).toBe(false);
  });
});
