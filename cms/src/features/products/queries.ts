import {
  PRODUCT_AUTH_DENIED_MESSAGE,
  PRODUCT_FILTER_OPTION_COLUMNS,
  PRODUCT_FILTER_OPTION_LIMIT,
  PRODUCT_IMAGE_LIST_COLUMNS,
  PRODUCT_INVENTORY_LIST_COLUMNS,
  PRODUCT_LIST_COLUMNS,
  PRODUCT_LOAD_FAILURE_MESSAGE,
  PRODUCT_NAME_LOOKUP_COLUMNS,
  PRODUCT_RELATED_FETCH_LIMIT,
  PRODUCT_VARIANT_LIST_COLUMNS,
} from "@/features/products/constants";
import { sanitizeProductProviderError } from "@/features/products/errors";
import { productMatchesStockFilter } from "@/features/products/inventory";
import {
  compareProductListItems,
  mapProductFilterOptionRow,
  mapProductImageRow,
  mapProductInventoryRow,
  mapProductListItem,
  mapProductNameRow,
  mapProductRow,
  mapProductVariantRow,
  type ProductInventoryRow,
  type ProductRow,
  type ProductVariantRow,
} from "@/features/products/mappers";
import { planProductSearch } from "@/features/products/search";
import type {
  ProductExplorerLoadResult,
  ProductExplorerQuery,
  ProductFilterOption,
  ProductListItem,
} from "@/features/products/types";
import {
  getProductListOrder,
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

export type ProductExplorerQueryClient = {
  auth: AuthorizationSupabaseClient["auth"];
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

    const searchPlan = planProductSearch(query.search);
    let productQuery = supabase
      .from("products")
      .select(PRODUCT_LIST_COLUMNS, { count: "exact" });

    if (query.categoryId) {
      productQuery = productQuery.eq("category_id", query.categoryId);
    }
    if (query.brandId) {
      productQuery = productQuery.eq("brand_id", query.brandId);
    }
    if (query.status) {
      productQuery = productQuery.eq("status", query.status);
    }
    if (searchPlan.kind === "or") {
      productQuery = productQuery.or(searchPlan.filter);
    } else if (searchPlan.kind === "none-match") {
      productQuery = productQuery.is("id", null);
    }

    for (const order of getProductListOrder(query.sort)) {
      productQuery = productQuery.order(order.column, {
        ascending: order.ascending,
      });
    }

    const { data, error, count } = await productQuery.range(
      query.pagination.from,
      query.pagination.to,
    );

    if (error || !Array.isArray(data)) {
      return {
        ok: false,
        message: sanitizeProductProviderError(error),
      };
    }

    const productRows: ProductRow[] = [];
    for (const row of data) {
      const mapped = mapProductRow(row);
      if (!mapped) {
        return { ok: false, message: PRODUCT_LOAD_FAILURE_MESSAGE };
      }
      productRows.push(mapped);
    }

    const related = await loadRelatedProductData(supabase, productRows);
    if (!related.ok) {
      return related;
    }

    const items: ProductListItem[] = [];
    for (const row of productRows) {
      const mapped = mapProductListItem({
        row,
        categoryName: related.categoryNameById.get(row.category_id) ?? null,
        brandName: row.brand_id
          ? (related.brandNameById.get(row.brand_id) ?? null)
          : null,
        variants: related.variantsByProductId.get(row.id) ?? [],
        inventoryByVariantId: related.inventoryByVariantId,
        primaryImagePath: related.primaryImageByProductId.get(row.id) ?? null,
        supabaseUrl,
      });
      if (!mapped) {
        return { ok: false, message: PRODUCT_LOAD_FAILURE_MESSAGE };
      }
      if (productMatchesStockFilter(mapped.inventory, query.stock)) {
        items.push(mapped);
      }
    }

    if (query.sort === "price_asc" || query.sort === "price_desc") {
      items.sort((left, right) =>
        compareProductListItems(left, right, query.sort),
      );
    }

    const totalCount = typeof count === "number" && count >= 0 ? count : 0;
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
  products: ProductRow[],
): Promise<
  | {
      ok: true;
      variantsByProductId: Map<string, ProductVariantRow[]>;
      inventoryByVariantId: Map<string, ProductInventoryRow>;
      primaryImageByProductId: Map<string, string>;
      categoryNameById: Map<string, string>;
      brandNameById: Map<string, string>;
    }
  | { ok: false; message: string }
> {
  const empty = {
    ok: true as const,
    variantsByProductId: new Map<string, ProductVariantRow[]>(),
    inventoryByVariantId: new Map<string, ProductInventoryRow>(),
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

  const variantsResult = await supabase
    .from("product_variants")
    .select(PRODUCT_VARIANT_LIST_COLUMNS)
    .in("product_id", productIds)
    .limit(PRODUCT_RELATED_FETCH_LIMIT);

  if (variantsResult.error || !Array.isArray(variantsResult.data)) {
    return { ok: false, message: PRODUCT_LOAD_FAILURE_MESSAGE };
  }
  if (variantsResult.data.length >= PRODUCT_RELATED_FETCH_LIMIT) {
    return { ok: false, message: PRODUCT_LOAD_FAILURE_MESSAGE };
  }

  const variantsByProductId = new Map<string, ProductVariantRow[]>();
  const variantIds: string[] = [];
  for (const row of variantsResult.data) {
    const mapped = mapProductVariantRow(row);
    if (!mapped) {
      return { ok: false, message: PRODUCT_LOAD_FAILURE_MESSAGE };
    }
    const current = variantsByProductId.get(mapped.product_id) ?? [];
    current.push(mapped);
    variantsByProductId.set(mapped.product_id, current);
    variantIds.push(mapped.id);
  }

  const [inventoryResult, imageResult, categoryResult, brandResult] =
    await Promise.all([
      loadBoundedRows(
        supabase,
        "inventory",
        PRODUCT_INVENTORY_LIST_COLUMNS,
        "variant_id",
        variantIds,
      ),
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

  if (
    !inventoryResult.ok ||
    !imageResult.ok ||
    !categoryResult.ok ||
    !brandResult.ok
  ) {
    return { ok: false, message: PRODUCT_LOAD_FAILURE_MESSAGE };
  }

  const inventoryByVariantId = new Map<string, ProductInventoryRow>();
  for (const row of inventoryResult.rows) {
    const mapped = mapProductInventoryRow(row);
    if (!mapped) {
      return { ok: false, message: PRODUCT_LOAD_FAILURE_MESSAGE };
    }
    inventoryByVariantId.set(mapped.variant_id, mapped);
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
    variantsByProductId,
    inventoryByVariantId,
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
  table: "inventory" | "categories" | "brands",
  columns: string,
  column: "id" | "variant_id",
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
