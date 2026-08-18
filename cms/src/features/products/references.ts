import {
  PRODUCT_INACTIVE_BRAND_MESSAGE,
  PRODUCT_INACTIVE_CATEGORY_MESSAGE,
  PRODUCT_PUBLISH_INACTIVE_CATEGORY_MESSAGE,
} from "@/features/products/constants";
import { PRODUCT_FILTER_OPTION_COLUMNS } from "@/features/products/constants";
import type { ProductStatus } from "@/features/products/types";
import { isValidUuid } from "@/features/products/validation";

type ReferenceRow = {
  id: string;
  is_active: boolean;
};

export type ProductReferenceQueryClient = {
  from: (table: "categories" | "brands") => {
    select: (columns: string) => {
      eq: (
        column: "id",
        value: string,
      ) => {
        maybeSingle: () => PromiseLike<{ data: unknown; error: unknown }>;
      };
    };
  };
};

export async function validateProductReferences(options: {
  supabase: ProductReferenceQueryClient | Record<string, unknown>;
  categoryId: string;
  brandId: string | null;
  status: ProductStatus;
  existingCategoryId?: string;
  existingBrandId?: string | null;
}): Promise<
  { ok: true } | { ok: false; message: string; field: "categoryId" | "brandId" }
> {
  const {
    supabase,
    categoryId,
    brandId,
    status,
    existingCategoryId,
    existingBrandId,
  } = options;

  const category = await loadReferenceRow(
    supabase as ProductReferenceQueryClient,
    "categories",
    categoryId,
  );
  if (!category.ok) {
    return {
      ok: false,
      message: PRODUCT_INACTIVE_CATEGORY_MESSAGE,
      field: "categoryId",
    };
  }

  const categoryChanged =
    existingCategoryId !== undefined && categoryId !== existingCategoryId;
  const keepingInactiveCategory =
    existingCategoryId === categoryId && !category.row.is_active;

  if (categoryChanged && !category.row.is_active) {
    return {
      ok: false,
      message: PRODUCT_INACTIVE_CATEGORY_MESSAGE,
      field: "categoryId",
    };
  }

  if (!existingCategoryId && !category.row.is_active) {
    return {
      ok: false,
      message: PRODUCT_INACTIVE_CATEGORY_MESSAGE,
      field: "categoryId",
    };
  }

  if (
    status === "active" &&
    !category.row.is_active &&
    !keepingInactiveCategory
  ) {
    return {
      ok: false,
      message: PRODUCT_PUBLISH_INACTIVE_CATEGORY_MESSAGE,
      field: "categoryId",
    };
  }

  if (status === "active" && keepingInactiveCategory) {
    return {
      ok: false,
      message: PRODUCT_PUBLISH_INACTIVE_CATEGORY_MESSAGE,
      field: "categoryId",
    };
  }

  if (brandId) {
    const brand = await loadReferenceRow(
      supabase as ProductReferenceQueryClient,
      "brands",
      brandId,
    );
    if (!brand.ok) {
      return {
        ok: false,
        message: PRODUCT_INACTIVE_BRAND_MESSAGE,
        field: "brandId",
      };
    }

    const brandChanged =
      existingBrandId !== undefined && brandId !== (existingBrandId ?? null);

    if (brandChanged && !brand.row.is_active) {
      return {
        ok: false,
        message: PRODUCT_INACTIVE_BRAND_MESSAGE,
        field: "brandId",
      };
    }

    if (existingBrandId === undefined && !brand.row.is_active) {
      return {
        ok: false,
        message: PRODUCT_INACTIVE_BRAND_MESSAGE,
        field: "brandId",
      };
    }
  }

  return { ok: true };
}

async function loadReferenceRow(
  supabase: ProductReferenceQueryClient,
  table: "categories" | "brands",
  id: string,
): Promise<{ ok: true; row: ReferenceRow } | { ok: false }> {
  if (!isValidUuid(id)) {
    return { ok: false };
  }

  try {
    const { data, error } = await supabase
      .from(table)
      .select(PRODUCT_FILTER_OPTION_COLUMNS)
      .eq("id", id)
      .maybeSingle();

    if (error || data === null || !isReferenceRow(data)) {
      return { ok: false };
    }

    return { ok: true, row: data };
  } catch {
    return { ok: false };
  }
}

function isReferenceRow(value: unknown): value is ReferenceRow {
  return (
    typeof value === "object" &&
    value !== null &&
    typeof (value as ReferenceRow).id === "string" &&
    typeof (value as ReferenceRow).is_active === "boolean"
  );
}
