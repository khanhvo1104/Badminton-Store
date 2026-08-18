import {
  getProductById,
  type ProductDetailQueryClient,
} from "@/features/products/detail-queries";
import { isValidUuid } from "@/features/products/validation";
import {
  GET_STAFF_VARIANT_COSTS_RPC,
  VARIANT_AUTH_DENIED_MESSAGE,
  VARIANT_LIST_MAX,
  VARIANT_LOAD_FAILURE_MESSAGE,
  VARIANT_NOT_FOUND_MESSAGE,
  VARIANT_PRODUCT_NOT_FOUND_MESSAGE,
  VARIANT_SAFE_COLUMNS,
} from "@/features/variants/constants";
import { sanitizeVariantProviderError } from "@/features/variants/errors";
import {
  mapVariantCostRow,
  mapVariantListItem,
  mapVariantSafeRow,
} from "@/features/variants/mappers";
import type {
  VariantEditorData,
  VariantListItem,
} from "@/features/variants/types";
import {
  type AuthorizationSupabaseClient,
  authorizeCmsRequest,
} from "@/lib/auth/authorization";

type QueryResponse = {
  data: unknown;
  error: unknown;
};

export type VariantQueryClient = {
  auth: AuthorizationSupabaseClient["auth"];
  rpc: (
    fn: typeof GET_STAFF_VARIANT_COSTS_RPC,
    args: { p_product_id: string },
  ) => PromiseLike<QueryResponse>;
  from: (table: "products" | "categories" | "brands" | "product_variants") => {
    select: (columns: string) => VariantSelectBuilder;
  };
};

type VariantSelectBuilder = {
  eq: (
    column: "id" | "product_id",
    value: string,
  ) => {
    maybeSingle: () => PromiseLike<QueryResponse>;
    order: (
      column: string,
      options?: { ascending?: boolean },
    ) => VariantOrderedBuilder;
  };
  order: (
    column: string,
    options?: { ascending?: boolean },
  ) => VariantOrderedBuilder;
};

type VariantOrderedBuilder = {
  order: (
    column: string,
    options?: { ascending?: boolean },
  ) => VariantOrderedBuilder;
  limit: (count: number) => PromiseLike<QueryResponse>;
};

export async function listProductVariants(options: {
  supabase: VariantQueryClient;
  productId: string;
}): Promise<
  | { ok: true; data: VariantEditorData }
  | { ok: false; message: string; notFound?: boolean }
> {
  const { supabase, productId } = options;

  if (!isValidUuid(productId)) {
    return {
      ok: false,
      message: VARIANT_PRODUCT_NOT_FOUND_MESSAGE,
      notFound: true,
    };
  }

  try {
    const authorization = await authorizeCmsRequest(
      supabase as unknown as AuthorizationSupabaseClient,
    );
    if (authorization.kind !== "authorized") {
      return { ok: false, message: VARIANT_AUTH_DENIED_MESSAGE };
    }

    const productResult = await getProductById({
      supabase: supabase as unknown as ProductDetailQueryClient,
      productId,
    });
    if (!productResult.ok && productResult.notFound) {
      return {
        ok: false,
        message: VARIANT_PRODUCT_NOT_FOUND_MESSAGE,
        notFound: true,
      };
    }
    if (!productResult.ok) {
      return { ok: false, message: productResult.message };
    }

    const { data, error } = await supabase
      .from("product_variants")
      .select(VARIANT_SAFE_COLUMNS)
      .eq("product_id", productId)
      .order("sort_order", { ascending: true })
      .order("id", { ascending: true })
      .limit(VARIANT_LIST_MAX + 1);

    if (error || !Array.isArray(data)) {
      return { ok: false, message: sanitizeVariantProviderError(error) };
    }
    if (data.length > VARIANT_LIST_MAX) {
      return { ok: false, message: VARIANT_LOAD_FAILURE_MESSAGE };
    }

    const rows = [];
    for (const entry of data) {
      const mapped = mapVariantSafeRow(entry);
      if (!mapped) {
        return { ok: false, message: VARIANT_LOAD_FAILURE_MESSAGE };
      }
      rows.push(mapped);
    }

    const { data: costData, error: costError } = await supabase.rpc(
      GET_STAFF_VARIANT_COSTS_RPC,
      { p_product_id: productId },
    );
    if (costError || !Array.isArray(costData)) {
      return { ok: false, message: sanitizeVariantProviderError(costError) };
    }

    const merged = mergeVariantCosts(rows, costData);
    if (!merged.ok) {
      return { ok: false, message: VARIANT_LOAD_FAILURE_MESSAGE };
    }

    return {
      ok: true,
      data: {
        productId,
        productName: productResult.product.name,
        variants: merged.items,
        isFirstVariant: merged.items.length === 0,
      },
    };
  } catch {
    return { ok: false, message: VARIANT_LOAD_FAILURE_MESSAGE };
  }
}

export async function getProductVariant(options: {
  supabase: VariantQueryClient;
  productId: string;
  variantId: string;
}): Promise<
  | { ok: true; data: VariantEditorData; variant: VariantListItem }
  | { ok: false; message: string; notFound?: boolean }
> {
  const { supabase, productId, variantId } = options;
  if (!isValidUuid(variantId)) {
    return {
      ok: false,
      message: VARIANT_NOT_FOUND_MESSAGE,
      notFound: true,
    };
  }

  const listed = await listProductVariants({ supabase, productId });
  if (!listed.ok) {
    return listed;
  }

  const variant = listed.data.variants.find((item) => item.id === variantId);
  if (!variant) {
    return {
      ok: false,
      message: VARIANT_NOT_FOUND_MESSAGE,
      notFound: true,
    };
  }

  return { ok: true, data: listed.data, variant };
}

export function mergeVariantCosts(
  rows: ReturnType<typeof mapVariantSafeRow>[],
  costData: unknown[],
): { ok: true; items: VariantListItem[] } | { ok: false } {
  const safeRows = rows.filter(
    (row): row is NonNullable<typeof row> => row !== null,
  );
  const costById = new Map<string, string | null>();

  for (const entry of costData) {
    const mapped = mapVariantCostRow(entry);
    if (!mapped) {
      return { ok: false };
    }
    if (costById.has(mapped.variant_id)) {
      return { ok: false };
    }
    costById.set(mapped.variant_id, mapped.cost_price);
  }

  const rowIds = new Set(safeRows.map((row) => row.id));
  if (costById.size !== rowIds.size) {
    return { ok: false };
  }
  for (const id of rowIds) {
    if (!costById.has(id)) {
      return { ok: false };
    }
  }
  for (const id of costById.keys()) {
    if (!rowIds.has(id)) {
      return { ok: false };
    }
  }

  return {
    ok: true,
    items: safeRows.map((row) =>
      mapVariantListItem(row, costById.get(row.id) ?? null),
    ),
  };
}
