import {
  LIST_CMS_PRODUCTS_RPC,
  PRODUCT_AUTH_DENIED_MESSAGE,
  PRODUCT_FILTER_OPTION_COLUMNS,
  PRODUCT_FILTER_OPTION_LIMIT,
  PRODUCT_IMAGE_LIST_COLUMNS,
  PRODUCT_LOAD_FAILURE_MESSAGE,
  PRODUCT_NAME_LOOKUP_COLUMNS,
  PRODUCT_RELATED_FETCH_LIMIT,
  PRODUCT_STATUS_LABELS,
} from "@/features/products/constants";
import { sanitizeProductProviderError } from "@/features/products/errors";
import { buildProductImagePublicUrl } from "@/features/products/image";
import {
  inventorySummaryFromRpc,
  mapCmsProductRpcRow,
  mapProductFilterOptionRow,
  mapProductImageRow,
  mapProductNameRow,
  type CmsProductRpcRow,
} from "@/features/products/mappers";
import { formatPriceRange } from "@/features/products/money";
import type {
  ProductExplorerLoadResult,
  ProductExplorerQuery,
  ProductFilterOption,
  ProductListItem,
} from "@/features/products/types";
import {
  getProductExplorerRpcArgs,
  productExplorerHasActiveFilters,
} from "@/features/products/validation";
import {
  type AuthorizationSupabaseClient,
  authorizeCmsRequest,
} from "@/lib/auth/authorization";

type QueryResponse = {
  data: unknown;
  error: unknown;
  count?: number | null;
};

export type ProductExplorerQueryBuilder = {
  select: (
    columns: string,
    options?: { count?: "exact"; head?: boolean },
  ) => ProductExplorerQueryBuilder;
  eq: (column: string, value: string | boolean) => ProductExplorerQueryBuilder;
  is: (column: string, value: null) => ProductExplorerQueryBuilder;
  in: (column: string, values: string[]) => ProductExplorerQueryBuilder;
  or: (filters: string) => ProductExplorerQueryBuilder;
  order: (
    column: string,
    options?: { ascending?: boolean },
  ) => ProductExplorerQueryBuilder;
  limit: (count: number) => PromiseLike<QueryResponse>;
  range: (from: number, to: number) => PromiseLike<QueryResponse>;
};

export type ProductExplorerRpcArgs = ReturnType<
  typeof getProductExplorerRpcArgs
>;

export type ProductExplorerQueryClient = {
  auth: AuthorizationSupabaseClient["auth"];
  rpc: (
    fn: typeof LIST_CMS_PRODUCTS_RPC,
    args: ProductExplorerRpcArgs,
  ) => PromiseLike<QueryResponse>;
  from: (
    table:
      | "products"
      | "product_variants"
      | "inventory"
      | "product_images"
      | "categories"
      | "brands"
      | "profiles",
  ) => ProductExplorerQueryBuilder;
};

export async function listProducts(options: {
  supabase: ProductExplorerQueryClient;
  query: ProductExplorerQuery;
  supabaseUrl: string;
}): Promise<ProductExplorerLoadResult> {
  const { supabase, query, supabaseUrl } = options;

  try {
    const authorization = await authorizeCmsRequest(
      supabase as unknown as AuthorizationSupabaseClient,
    );
    if (authorization.kind !== "authorized") {
      return { ok: false, message: PRODUCT_AUTH_DENIED_MESSAGE };
    }

    const rpcArgs = getProductExplorerRpcArgs(query);
    const { data, error } = await supabase.rpc(LIST_CMS_PRODUCTS_RPC, rpcArgs);

    if (error || !Array.isArray(data)) {
      return {
        ok: false,
        message: sanitizeProductProviderError(error),
      };
    }

    const rpcRows: CmsProductRpcRow[] = [];
    for (const row of data) {
      const mapped = mapCmsProductRpcRow(row);
      if (!mapped) {
        return { ok: false, message: PRODUCT_LOAD_FAILURE_MESSAGE };
      }
      rpcRows.push(mapped);
    }

    const totalCount = rpcRows[0]?.filtered_count ?? 0;
    const productRows = rpcRows.filter(
      (row): row is CmsProductRpcRow & { id: string } => row.id !== null,
    );

    const related = await loadRelatedProductData(
      supabase,
      productRows.map((row) => ({
        id: row.id,
        category_id: row.category_id ?? "",
        brand_id: row.brand_id,
      })),
    );
    if (!related.ok) {
      return related;
    }

    const items: ProductListItem[] = [];
    for (const row of productRows) {
      const mapped = mapRpcListItem({
        row,
        categoryName: row.category_id
          ? (related.categoryNameById.get(row.category_id) ?? null)
          : null,
        brandName: row.brand_id
          ? (related.brandNameById.get(row.brand_id) ?? null)
          : null,
        primaryImagePath: related.primaryImageByProductId.get(row.id) ?? null,
        supabaseUrl,
      });
      if (!mapped) {
        return { ok: false, message: PRODUCT_LOAD_FAILURE_MESSAGE };
      }
      items.push(mapped);
    }

    const totalPages =
      totalCount === 0 ? 0 : Math.ceil(totalCount / query.pagination.pageSize);

    return {
      ok: true,
      result: {
        items,
        totalCount,
        pagination: query.pagination,
        totalPages,
        query,
        hasActiveFilters: productExplorerHasActiveFilters(query),
      },
    };
  } catch {
    return { ok: false, message: PRODUCT_LOAD_FAILURE_MESSAGE };
  }
}

export async function listProductCategoryOptions(options: {
  supabase: ProductExplorerQueryClient;
}): Promise<
  { ok: true; options: ProductFilterOption[] } | { ok: false; message: string }
> {
  return listFilterOptions(options.supabase, "categories");
}

export async function listProductBrandOptions(options: {
  supabase: ProductExplorerQueryClient;
}): Promise<
  { ok: true; options: ProductFilterOption[] } | { ok: false; message: string }
> {
  return listFilterOptions(options.supabase, "brands");
}

function mapRpcListItem(options: {
  row: CmsProductRpcRow & { id: string };
  categoryName: string | null;
  brandName: string | null;
  primaryImagePath: string | null;
  supabaseUrl: string;
}): ProductListItem | null {
  const { row, categoryName, brandName, primaryImagePath, supabaseUrl } =
    options;
  if (
    !row.category_id ||
    !row.name ||
    !row.slug ||
    !row.status ||
    typeof row.is_featured !== "boolean" ||
    !row.updated_at ||
    row.active_variant_count === null ||
    row.total_variant_count === null
  ) {
    return null;
  }

  const inventory = inventorySummaryFromRpc(row);
  if (!inventory) {
    return null;
  }

  return {
    id: row.id,
    name: row.name,
    slug: row.slug,
    categoryId: row.category_id,
    categoryName,
    brandId: row.brand_id,
    brandName,
    status: row.status,
    statusLabel: PRODUCT_STATUS_LABELS[row.status],
    isFeatured: row.is_featured,
    featuredLabel: row.is_featured ? "Featured" : "Not featured",
    publishedAt: row.published_at,
    publishedAtLabel: formatTimestamp(row.published_at),
    updatedAt: row.updated_at,
    updatedAtLabel: formatTimestamp(row.updated_at),
    primaryImageUrl: buildProductImagePublicUrl(supabaseUrl, primaryImagePath),
    activeVariantCount: row.active_variant_count,
    totalVariantCount: row.total_variant_count,
    priceRange: {
      minAmount: row.min_price,
      maxAmount: row.max_price,
      label: formatPriceRange(row.min_price, row.max_price),
    },
    inventory,
  };
}

function formatTimestamp(value: string | null): string {
  if (!value) {
    return "Not published";
  }

  return new Intl.DateTimeFormat("en-GB", {
    dateStyle: "medium",
    timeStyle: "short",
    timeZone: "UTC",
  }).format(new Date(value));
}

async function listFilterOptions(
  supabase: ProductExplorerQueryClient,
  table: "categories" | "brands",
): Promise<
  { ok: true; options: ProductFilterOption[] } | { ok: false; message: string }
> {
  try {
    const { data, error } = await supabase
      .from(table)
      .select(PRODUCT_FILTER_OPTION_COLUMNS)
      .order("name", { ascending: true })
      .order("id", { ascending: true })
      .limit(PRODUCT_FILTER_OPTION_LIMIT);

    if (error || !Array.isArray(data)) {
      return { ok: false, message: PRODUCT_LOAD_FAILURE_MESSAGE };
    }

    if (data.length >= PRODUCT_FILTER_OPTION_LIMIT) {
      return { ok: false, message: PRODUCT_LOAD_FAILURE_MESSAGE };
    }

    const options: ProductFilterOption[] = [];
    for (const row of data) {
      const mapped = mapProductFilterOptionRow(row);
      if (!mapped) {
        return { ok: false, message: PRODUCT_LOAD_FAILURE_MESSAGE };
      }
      options.push({
        id: mapped.id,
        name: mapped.name,
        isActive: mapped.is_active,
      });
    }

    return { ok: true, options };
  } catch {
    return { ok: false, message: PRODUCT_LOAD_FAILURE_MESSAGE };
  }
}

async function loadRelatedProductData(
  supabase: ProductExplorerQueryClient,
  products: Array<{ id: string; category_id: string; brand_id: string | null }>,
): Promise<
  | {
      ok: true;
      primaryImageByProductId: Map<string, string>;
      categoryNameById: Map<string, string>;
      brandNameById: Map<string, string>;
    }
  | { ok: false; message: string }
> {
  const empty = {
    ok: true as const,
    primaryImageByProductId: new Map<string, string>(),
    categoryNameById: new Map<string, string>(),
    brandNameById: new Map<string, string>(),
  };

  if (products.length === 0) {
    return empty;
  }

  const productIds = products.map((product) => product.id);
  const categoryIds = uniqueIds(products.map((product) => product.category_id));
  const brandIds = uniqueIds(
    products
      .map((product) => product.brand_id)
      .filter((value): value is string => typeof value === "string"),
  );

  const [imageResult, categoryResult, brandResult] = await Promise.all([
    loadPrimaryImages(supabase, productIds),
    loadBoundedRows(
      supabase,
      "categories",
      PRODUCT_NAME_LOOKUP_COLUMNS,
      "id",
      categoryIds,
    ),
    loadBoundedRows(
      supabase,
      "brands",
      PRODUCT_NAME_LOOKUP_COLUMNS,
      "id",
      brandIds,
    ),
  ]);

  if (!imageResult.ok || !categoryResult.ok || !brandResult.ok) {
    return { ok: false, message: PRODUCT_LOAD_FAILURE_MESSAGE };
  }

  const primaryImageByProductId = new Map<string, string>();
  for (const row of imageResult.rows) {
    const mapped = mapProductImageRow(row);
    if (!mapped) {
      return { ok: false, message: PRODUCT_LOAD_FAILURE_MESSAGE };
    }
    if (mapped.variant_id !== null || mapped.is_primary !== true) {
      return { ok: false, message: PRODUCT_LOAD_FAILURE_MESSAGE };
    }
    primaryImageByProductId.set(mapped.product_id, mapped.storage_path);
  }

  const categoryNameById = new Map<string, string>();
  for (const row of categoryResult.rows) {
    const mapped = mapProductNameRow(row);
    if (!mapped) {
      return { ok: false, message: PRODUCT_LOAD_FAILURE_MESSAGE };
    }
    categoryNameById.set(mapped.id, mapped.name);
  }

  const brandNameById = new Map<string, string>();
  for (const row of brandResult.rows) {
    const mapped = mapProductNameRow(row);
    if (!mapped) {
      return { ok: false, message: PRODUCT_LOAD_FAILURE_MESSAGE };
    }
    brandNameById.set(mapped.id, mapped.name);
  }

  return {
    ok: true,
    primaryImageByProductId,
    categoryNameById,
    brandNameById,
  };
}

async function loadPrimaryImages(
  supabase: ProductExplorerQueryClient,
  productIds: string[],
): Promise<{ ok: true; rows: unknown[] } | { ok: false }> {
  if (productIds.length === 0) {
    return { ok: true, rows: [] };
  }

  try {
    const { data, error } = await supabase
      .from("product_images")
      .select(PRODUCT_IMAGE_LIST_COLUMNS)
      .in("product_id", productIds)
      .is("variant_id", null)
      .eq("is_primary", true)
      .limit(productIds.length);

    if (error || !Array.isArray(data) || data.length > productIds.length) {
      return { ok: false };
    }

    return { ok: true, rows: data };
  } catch {
    return { ok: false };
  }
}

async function loadBoundedRows(
  supabase: ProductExplorerQueryClient,
  table: "categories" | "brands",
  columns: string,
  column: "id",
  ids: string[],
): Promise<{ ok: true; rows: unknown[] } | { ok: false }> {
  if (ids.length === 0) {
    return { ok: true, rows: [] };
  }

  try {
    const { data, error } = await supabase
      .from(table)
      .select(columns)
      .in(column, ids)
      .limit(PRODUCT_RELATED_FETCH_LIMIT);

    if (error || !Array.isArray(data)) {
      return { ok: false };
    }
    if (data.length >= PRODUCT_RELATED_FETCH_LIMIT) {
      return { ok: false };
    }

    return { ok: true, rows: data };
  } catch {
    return { ok: false };
  }
}

function uniqueIds(values: string[]): string[] {
  return [...new Set(values)];
}
