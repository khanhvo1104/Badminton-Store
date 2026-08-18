import {
  PRODUCT_DETAIL_COLUMNS,
  PRODUCT_FILTER_OPTION_COLUMNS,
  PRODUCT_FILTER_OPTION_LIMIT,
  PRODUCT_GENERIC_FAILURE_MESSAGE,
  PRODUCT_NAME_LOOKUP_COLUMNS,
  PRODUCT_NOT_FOUND_MESSAGE,
  PRODUCT_STATUS_LABELS,
} from "@/features/products/constants";
import {
  isProductDetailRow,
  mapProductDetail,
} from "@/features/products/mappers";
import type {
  ProductDetail,
  ProductFormReferenceOption,
} from "@/features/products/types";
import { isValidUuid } from "@/features/products/validation";

export type ProductDetailQueryClient = {
  from: (table: "products" | "categories" | "brands") => {
    select: (columns: string) => ProductDetailSelectBuilder;
  };
};

type ProductDetailSelectBuilder = {
  eq: (
    column: "id",
    value: string,
  ) => {
    maybeSingle: () => PromiseLike<{ data: unknown; error: unknown }>;
  };
  order: (
    column: string,
    options?: { ascending?: boolean },
  ) => ProductDetailOptionsBuilder;
  in: (
    column: "id",
    values: string[],
  ) => PromiseLike<{ data: unknown; error: unknown }>;
  limit: (count: number) => PromiseLike<{ data: unknown; error: unknown }>;
};

type ProductDetailOptionsBuilder = {
  order: (
    column: string,
    options?: { ascending?: boolean },
  ) => ProductDetailOptionsBuilder;
  limit: (count: number) => PromiseLike<{ data: unknown; error: unknown }>;
};

export async function getProductById(options: {
  supabase: ProductDetailQueryClient;
  productId: string;
}): Promise<
  | { ok: true; product: ProductDetail }
  | { ok: false; message: string; notFound?: boolean }
> {
  const { supabase, productId } = options;

  if (!isValidUuid(productId)) {
    return {
      ok: false,
      message: PRODUCT_NOT_FOUND_MESSAGE,
      notFound: true,
    };
  }

  try {
    const { data, error } = await supabase
      .from("products")
      .select(PRODUCT_DETAIL_COLUMNS)
      .eq("id", productId)
      .maybeSingle();

    if (error) {
      return { ok: false, message: PRODUCT_GENERIC_FAILURE_MESSAGE };
    }

    if (data === null) {
      return {
        ok: false,
        message: PRODUCT_NOT_FOUND_MESSAGE,
        notFound: true,
      };
    }

    if (!isProductDetailRow(data)) {
      return { ok: false, message: PRODUCT_GENERIC_FAILURE_MESSAGE };
    }

    const [categoryName, brandName] = await Promise.all([
      loadReferenceName(supabase, "categories", data.category_id),
      data.brand_id
        ? loadReferenceName(supabase, "brands", data.brand_id)
        : Promise.resolve(null),
    ]);

    return {
      ok: true,
      product: mapProductDetail({
        row: data,
        categoryName,
        brandName,
      }),
    };
  } catch {
    return { ok: false, message: PRODUCT_GENERIC_FAILURE_MESSAGE };
  }
}

export async function listProductFormReferenceOptions(options: {
  supabase: ProductDetailQueryClient;
  includeCategoryIds?: string[];
  includeBrandIds?: string[];
}): Promise<
  | {
      ok: true;
      categories: ProductFormReferenceOption[];
      brands: ProductFormReferenceOption[];
    }
  | { ok: false; message: string }
> {
  const { supabase, includeCategoryIds = [], includeBrandIds = [] } = options;

  try {
    const [categoriesResult, brandsResult] = await Promise.all([
      loadFormOptions(supabase, "categories", includeCategoryIds),
      loadFormOptions(supabase, "brands", includeBrandIds),
    ]);

    if (!categoriesResult.ok || !brandsResult.ok) {
      return { ok: false, message: PRODUCT_GENERIC_FAILURE_MESSAGE };
    }

    return {
      ok: true,
      categories: categoriesResult.options,
      brands: brandsResult.options,
    };
  } catch {
    return { ok: false, message: PRODUCT_GENERIC_FAILURE_MESSAGE };
  }
}

async function loadReferenceName(
  supabase: ProductDetailQueryClient,
  table: "categories" | "brands",
  id: string,
): Promise<string | null> {
  try {
    const { data, error } = await supabase
      .from(table)
      .select(PRODUCT_NAME_LOOKUP_COLUMNS)
      .eq("id", id)
      .maybeSingle();

    if (error || data === null || !isNameRow(data)) {
      return null;
    }

    return data.name;
  } catch {
    return null;
  }
}

async function loadFormOptions(
  supabase: ProductDetailQueryClient,
  table: "categories" | "brands",
  includeInactiveIds: string[],
): Promise<
  { ok: true; options: ProductFormReferenceOption[] } | { ok: false }
> {
  const { data, error } = await supabase
    .from(table)
    .select(PRODUCT_FILTER_OPTION_COLUMNS)
    .order("name", { ascending: true })
    .order("id", { ascending: true })
    .limit(PRODUCT_FILTER_OPTION_LIMIT);

  if (error || !Array.isArray(data)) {
    return { ok: false };
  }

  if (data.length >= PRODUCT_FILTER_OPTION_LIMIT) {
    return { ok: false };
  }

  const options = new Map<string, ProductFormReferenceOption>();

  for (const row of data) {
    const mapped = mapReferenceOption(row);
    if (!mapped) {
      return { ok: false };
    }
    if (mapped.isActive) {
      options.set(mapped.id, mapped);
    }
  }

  for (const id of includeInactiveIds) {
    if (!isValidUuid(id) || options.has(id)) {
      continue;
    }

    const { data: inactiveRow, error: inactiveError } = await supabase
      .from(table)
      .select(PRODUCT_FILTER_OPTION_COLUMNS)
      .eq("id", id)
      .maybeSingle();

    if (inactiveError || inactiveRow === null) {
      continue;
    }

    const mapped = mapReferenceOption(inactiveRow);
    if (!mapped) {
      return { ok: false };
    }
    options.set(mapped.id, mapped);
  }

  return {
    ok: true,
    options: [...options.values()].sort((left, right) =>
      left.name.localeCompare(right.name),
    ),
  };
}

function mapReferenceOption(value: unknown): ProductFormReferenceOption | null {
  if (
    typeof value !== "object" ||
    value === null ||
    typeof (value as { id?: unknown }).id !== "string" ||
    typeof (value as { name?: unknown }).name !== "string" ||
    typeof (value as { is_active?: unknown }).is_active !== "boolean"
  ) {
    return null;
  }

  return {
    id: (value as { id: string }).id,
    name: (value as { name: string }).name,
    isActive: (value as { is_active: boolean }).is_active,
  };
}

function isNameRow(value: unknown): value is { id: string; name: string } {
  return (
    typeof value === "object" &&
    value !== null &&
    typeof (value as { id?: unknown }).id === "string" &&
    typeof (value as { name?: unknown }).name === "string"
  );
}

export function formatProductStatusLabel(
  status: ProductDetail["status"],
): string {
  return PRODUCT_STATUS_LABELS[status];
}
