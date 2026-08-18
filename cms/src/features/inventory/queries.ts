import {
  ADJUST_CMS_INVENTORY_RPC,
  INVENTORY_ACTOR_COLUMNS,
  INVENTORY_AUTH_DENIED_MESSAGE,
  INVENTORY_HISTORY_COLUMNS,
  INVENTORY_HISTORY_LIMIT,
  INVENTORY_LOAD_FAILURE_MESSAGE,
  INVENTORY_NOT_FOUND_MESSAGE,
  INVENTORY_PRODUCT_COLUMNS,
  INVENTORY_ROW_COLUMNS,
  INVENTORY_VARIANT_COLUMNS,
  LIST_CMS_INVENTORY_RPC,
} from "@/features/inventory/constants";
import { sanitizeInventoryProviderError } from "@/features/inventory/errors";
import {
  buildInventoryDetail,
  mapCmsInventoryRpcRow,
  mapInventoryHistoryRow,
  mapInventoryListItem,
  mapInventoryProductRow,
  mapInventoryRow,
  mapInventoryVariantRow,
  toHistoryItem,
  type CmsInventoryRpcRow,
} from "@/features/inventory/mappers";
import type {
  InventoryDetailLoadResult,
  InventoryExplorerLoadResult,
  InventoryExplorerQuery,
  InventoryHistoryItem,
  InventoryListItem,
} from "@/features/inventory/types";
import {
  getInventoryExplorerRpcArgs,
  inventoryExplorerHasActiveFilters,
} from "@/features/inventory/validation";
import {
  type AuthorizationSupabaseClient,
  authorizeCmsRequest,
} from "@/lib/auth/authorization";
import { isValidUuid } from "@/features/products/validation";

type QueryResponse = {
  data: unknown;
  error: unknown;
};

export type InventoryExplorerRpcArgs = ReturnType<
  typeof getInventoryExplorerRpcArgs
>;

export type InventoryQueryClient = {
  auth: AuthorizationSupabaseClient["auth"];
  rpc: (
    fn: typeof LIST_CMS_INVENTORY_RPC | typeof ADJUST_CMS_INVENTORY_RPC,
    args: InventoryExplorerRpcArgs | Record<string, unknown>,
  ) => PromiseLike<QueryResponse>;
  from: (
    table:
      | "product_variants"
      | "products"
      | "inventory"
      | "inventory_history"
      | "profiles",
  ) => {
    select: (columns: string) => InventorySelectBuilder;
  };
};

type InventorySelectBuilder = {
  eq: (
    column: "id" | "variant_id",
    value: string,
  ) => {
    maybeSingle: () => PromiseLike<QueryResponse>;
    order: (
      column: string,
      options?: { ascending?: boolean },
    ) => InventoryOrderedBuilder;
  };
  in: (
    column: "id",
    values: string[],
  ) => {
    limit: (count: number) => PromiseLike<QueryResponse>;
  };
};

type InventoryOrderedBuilder = {
  order: (
    column: string,
    options?: { ascending?: boolean },
  ) => InventoryOrderedBuilder;
  limit: (count: number) => PromiseLike<QueryResponse>;
};

export async function listInventory(options: {
  supabase: InventoryQueryClient;
  query: InventoryExplorerQuery;
}): Promise<InventoryExplorerLoadResult> {
  const { supabase, query } = options;

  try {
    const authorization = await authorizeCmsRequest(
      supabase as unknown as AuthorizationSupabaseClient,
    );
    if (authorization.kind !== "authorized") {
      return { ok: false, message: INVENTORY_AUTH_DENIED_MESSAGE };
    }

    const rpcArgs = getInventoryExplorerRpcArgs(query);
    const { data, error } = await supabase.rpc(LIST_CMS_INVENTORY_RPC, rpcArgs);

    if (error || !Array.isArray(data)) {
      return { ok: false, message: sanitizeInventoryProviderError(error) };
    }

    const rpcRows: CmsInventoryRpcRow[] = [];
    for (const row of data) {
      const mapped = mapCmsInventoryRpcRow(row);
      if (!mapped) {
        return { ok: false, message: INVENTORY_LOAD_FAILURE_MESSAGE };
      }
      rpcRows.push(mapped);
    }

    const totalCount = rpcRows[0]?.filtered_count ?? 0;
    const items: InventoryListItem[] = [];
    for (const row of rpcRows) {
      if (row.variant_id === null) {
        continue;
      }
      const mapped = mapInventoryListItem(
        row as CmsInventoryRpcRow & { variant_id: string },
      );
      if (!mapped) {
        return { ok: false, message: INVENTORY_LOAD_FAILURE_MESSAGE };
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
        hasActiveFilters: inventoryExplorerHasActiveFilters(query),
      },
    };
  } catch {
    return { ok: false, message: INVENTORY_LOAD_FAILURE_MESSAGE };
  }
}

export async function getInventoryVariant(options: {
  supabase: InventoryQueryClient;
  variantId: string;
}): Promise<InventoryDetailLoadResult> {
  const { supabase, variantId } = options;

  if (!isValidUuid(variantId)) {
    return {
      ok: false,
      message: INVENTORY_NOT_FOUND_MESSAGE,
      notFound: true,
    };
  }

  try {
    const authorization = await authorizeCmsRequest(
      supabase as unknown as AuthorizationSupabaseClient,
    );
    if (authorization.kind !== "authorized") {
      return { ok: false, message: INVENTORY_AUTH_DENIED_MESSAGE };
    }

    const variantResult = await supabase
      .from("product_variants")
      .select(INVENTORY_VARIANT_COLUMNS)
      .eq("id", variantId)
      .maybeSingle();

    if (variantResult.error) {
      return {
        ok: false,
        message: sanitizeInventoryProviderError(variantResult.error),
      };
    }
    if (!variantResult.data) {
      return {
        ok: false,
        message: INVENTORY_NOT_FOUND_MESSAGE,
        notFound: true,
      };
    }

    const variant = mapInventoryVariantRow(variantResult.data);
    if (!variant) {
      return { ok: false, message: INVENTORY_LOAD_FAILURE_MESSAGE };
    }

    const [productResult, inventoryResult, historyResult] = await Promise.all([
      supabase
        .from("products")
        .select(INVENTORY_PRODUCT_COLUMNS)
        .eq("id", variant.product_id)
        .maybeSingle(),
      supabase
        .from("inventory")
        .select(INVENTORY_ROW_COLUMNS)
        .eq("variant_id", variantId)
        .maybeSingle(),
      supabase
        .from("inventory_history")
        .select(INVENTORY_HISTORY_COLUMNS)
        .eq("variant_id", variantId)
        .order("created_at", { ascending: false })
        .order("id", { ascending: false })
        .limit(INVENTORY_HISTORY_LIMIT),
    ]);

    if (productResult.error || !productResult.data) {
      return {
        ok: false,
        message: productResult.error
          ? sanitizeInventoryProviderError(productResult.error)
          : INVENTORY_LOAD_FAILURE_MESSAGE,
      };
    }

    const product = mapInventoryProductRow(productResult.data);
    if (!product) {
      return { ok: false, message: INVENTORY_LOAD_FAILURE_MESSAGE };
    }

    if (inventoryResult.error) {
      return {
        ok: false,
        message: sanitizeInventoryProviderError(inventoryResult.error),
      };
    }

    const inventory = inventoryResult.data
      ? mapInventoryRow(inventoryResult.data)
      : null;
    if (inventoryResult.data && !inventory) {
      return { ok: false, message: INVENTORY_LOAD_FAILURE_MESSAGE };
    }

    if (historyResult.error || !Array.isArray(historyResult.data)) {
      return {
        ok: false,
        message: sanitizeInventoryProviderError(historyResult.error),
      };
    }
    if (historyResult.data.length > INVENTORY_HISTORY_LIMIT) {
      return { ok: false, message: INVENTORY_LOAD_FAILURE_MESSAGE };
    }

    const historyRows = [];
    for (const row of historyResult.data) {
      const mapped = mapInventoryHistoryRow(row);
      if (!mapped) {
        return { ok: false, message: INVENTORY_LOAD_FAILURE_MESSAGE };
      }
      historyRows.push(mapped);
    }

    const actorIds = [...new Set(historyRows.map((row) => row.actor_id))];
    const actorNameById = new Map<string, string>();
    if (actorIds.length > 0) {
      const actorsResult = await supabase
        .from("profiles")
        .select(INVENTORY_ACTOR_COLUMNS)
        .in("id", actorIds)
        .limit(actorIds.length);

      if (actorsResult.error || !Array.isArray(actorsResult.data)) {
        return {
          ok: false,
          message: sanitizeInventoryProviderError(actorsResult.error),
        };
      }

      for (const row of actorsResult.data) {
        if (!isRecord(row) || typeof row.id !== "string") {
          return { ok: false, message: INVENTORY_LOAD_FAILURE_MESSAGE };
        }
        const name =
          typeof row.full_name === "string" && row.full_name.trim()
            ? row.full_name.trim()
            : "Staff";
        actorNameById.set(row.id, name);
      }
    }

    const history: InventoryHistoryItem[] = historyRows.map((row) =>
      toHistoryItem(row, actorNameById.get(row.actor_id) ?? "Staff"),
    );

    return {
      ok: true,
      detail: buildInventoryDetail({
        variantId: variant.id,
        productId: variant.product_id,
        productName: product.name,
        variantName: variant.name,
        sku: variant.sku,
        inventory,
        history,
      }),
    };
  } catch {
    return { ok: false, message: INVENTORY_LOAD_FAILURE_MESSAGE };
  }
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null;
}
