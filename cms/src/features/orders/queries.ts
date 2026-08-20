import {
  LIST_CMS_ORDERS_RPC,
  ORDER_ACTOR_COLUMNS,
  ORDER_DETAIL_COLUMNS,
  ORDER_HISTORY_COLUMNS,
  ORDER_ITEM_COLUMNS,
  ORDERS_AUTH_DENIED_MESSAGE,
  ORDERS_HISTORY_LIMIT,
  ORDERS_ITEMS_LIMIT,
  ORDERS_LOAD_FAILURE_MESSAGE,
  ORDERS_NOT_FOUND_MESSAGE,
  TRANSITION_CMS_ORDER_STATUS_RPC,
} from "@/features/orders/constants";
import { sanitizeOrdersProviderError } from "@/features/orders/errors";
import {
  buildOrderDetail,
  mapCmsOrderRpcRow,
  mapOrderDetailRow,
  mapOrderHistoryRow,
  mapOrderItemRow,
  mapOrderListItem,
  toHistoryItem,
  type CmsOrderRpcRow,
} from "@/features/orders/mappers";
import type {
  OrderDetailLoadResult,
  OrderHistoryItem,
  OrderItemSnapshot,
  OrderListItem,
  OrdersExplorerLoadResult,
  OrdersExplorerQuery,
} from "@/features/orders/types";
import {
  getOrdersExplorerRpcArgs,
  ordersExplorerHasActiveFilters,
} from "@/features/orders/validation";
import {
  type AuthorizationSupabaseClient,
  authorizeCmsRequest,
} from "@/lib/auth/authorization";
import { isValidUuid } from "@/features/products/validation";

type QueryResponse = {
  data: unknown;
  error: unknown;
};

export type OrdersExplorerRpcArgs = ReturnType<typeof getOrdersExplorerRpcArgs>;

export type OrdersQueryClient = {
  auth: AuthorizationSupabaseClient["auth"];
  rpc: (
    fn: typeof LIST_CMS_ORDERS_RPC | typeof TRANSITION_CMS_ORDER_STATUS_RPC,
    args: OrdersExplorerRpcArgs | Record<string, unknown>,
  ) => PromiseLike<QueryResponse>;
  from: (
    table: "orders" | "order_items" | "order_status_history" | "profiles",
  ) => {
    select: (columns: string) => OrdersSelectBuilder;
  };
};

type OrdersSelectBuilder = {
  eq: (
    column: "id" | "order_id",
    value: string,
  ) => {
    maybeSingle: () => PromiseLike<QueryResponse>;
    order: (
      column: string,
      options?: { ascending?: boolean },
    ) => OrdersOrderedBuilder;
  };
  in: (
    column: "id",
    values: string[],
  ) => {
    limit: (count: number) => PromiseLike<QueryResponse>;
  };
};

type OrdersOrderedBuilder = {
  order: (
    column: string,
    options?: { ascending?: boolean },
  ) => OrdersOrderedBuilder;
  limit: (count: number) => PromiseLike<QueryResponse>;
};

export async function listOrders(options: {
  supabase: OrdersQueryClient;
  query: OrdersExplorerQuery;
}): Promise<OrdersExplorerLoadResult> {
  const { supabase, query } = options;

  try {
    const authorization = await authorizeCmsRequest(
      supabase as unknown as AuthorizationSupabaseClient,
    );
    if (authorization.kind !== "authorized") {
      return { ok: false, message: ORDERS_AUTH_DENIED_MESSAGE };
    }

    const rpcArgs = getOrdersExplorerRpcArgs(query);
    const { data, error } = await supabase.rpc(LIST_CMS_ORDERS_RPC, rpcArgs);

    if (error || !Array.isArray(data)) {
      return { ok: false, message: sanitizeOrdersProviderError(error) };
    }

    const rpcRows: CmsOrderRpcRow[] = [];
    for (const row of data) {
      const mapped = mapCmsOrderRpcRow(row);
      if (!mapped) {
        return { ok: false, message: ORDERS_LOAD_FAILURE_MESSAGE };
      }
      rpcRows.push(mapped);
    }

    const totalCount = rpcRows[0]?.filtered_count ?? 0;
    const items: OrderListItem[] = [];
    for (const row of rpcRows) {
      if (row.order_id === null) {
        continue;
      }
      const mapped = mapOrderListItem(
        row as CmsOrderRpcRow & { order_id: string },
      );
      if (!mapped) {
        return { ok: false, message: ORDERS_LOAD_FAILURE_MESSAGE };
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
        hasActiveFilters: ordersExplorerHasActiveFilters(query),
      },
    };
  } catch {
    return { ok: false, message: ORDERS_LOAD_FAILURE_MESSAGE };
  }
}

export async function getOrderDetail(options: {
  supabase: OrdersQueryClient;
  orderId: string;
}): Promise<OrderDetailLoadResult> {
  const { supabase, orderId } = options;

  if (!isValidUuid(orderId)) {
    return {
      ok: false,
      message: ORDERS_NOT_FOUND_MESSAGE,
      notFound: true,
    };
  }

  try {
    const authorization = await authorizeCmsRequest(
      supabase as unknown as AuthorizationSupabaseClient,
    );
    if (authorization.kind !== "authorized") {
      return { ok: false, message: ORDERS_AUTH_DENIED_MESSAGE };
    }

    const orderResult = await supabase
      .from("orders")
      .select(ORDER_DETAIL_COLUMNS)
      .eq("id", orderId)
      .maybeSingle();

    if (orderResult.error) {
      return {
        ok: false,
        message: sanitizeOrdersProviderError(orderResult.error),
      };
    }
    if (!orderResult.data) {
      return {
        ok: false,
        message: ORDERS_NOT_FOUND_MESSAGE,
        notFound: true,
      };
    }

    const order = mapOrderDetailRow(orderResult.data);
    if (!order) {
      return { ok: false, message: ORDERS_LOAD_FAILURE_MESSAGE };
    }

    const [itemsResult, historyResult] = await Promise.all([
      supabase
        .from("order_items")
        .select(ORDER_ITEM_COLUMNS)
        .eq("order_id", orderId)
        .order("created_at", { ascending: true })
        .order("id", { ascending: true })
        .limit(ORDERS_ITEMS_LIMIT + 1),
      supabase
        .from("order_status_history")
        .select(ORDER_HISTORY_COLUMNS)
        .eq("order_id", orderId)
        .order("created_at", { ascending: false })
        .order("id", { ascending: false })
        .limit(ORDERS_HISTORY_LIMIT + 1),
    ]);

    if (itemsResult.error || !Array.isArray(itemsResult.data)) {
      return {
        ok: false,
        message: sanitizeOrdersProviderError(itemsResult.error),
      };
    }
    if (itemsResult.data.length > ORDERS_ITEMS_LIMIT) {
      return { ok: false, message: ORDERS_LOAD_FAILURE_MESSAGE };
    }

    const items: OrderItemSnapshot[] = [];
    for (const row of itemsResult.data) {
      const mapped = mapOrderItemRow(row, order.currency_code);
      if (!mapped) {
        return { ok: false, message: ORDERS_LOAD_FAILURE_MESSAGE };
      }
      items.push(mapped);
    }

    if (historyResult.error || !Array.isArray(historyResult.data)) {
      return {
        ok: false,
        message: sanitizeOrdersProviderError(historyResult.error),
      };
    }
    if (historyResult.data.length > ORDERS_HISTORY_LIMIT) {
      return { ok: false, message: ORDERS_LOAD_FAILURE_MESSAGE };
    }

    const historyRows = [];
    for (const row of historyResult.data) {
      const mapped = mapOrderHistoryRow(row);
      if (!mapped) {
        return { ok: false, message: ORDERS_LOAD_FAILURE_MESSAGE };
      }
      historyRows.push(mapped);
    }

    const actorIds = [
      ...new Set(
        historyRows
          .map((row) => row.changed_by)
          .filter((id): id is string => typeof id === "string"),
      ),
    ];
    const actorNameById = new Map<string, string>();
    if (actorIds.length > 0) {
      const actorsResult = await supabase
        .from("profiles")
        .select(ORDER_ACTOR_COLUMNS)
        .in("id", actorIds)
        .limit(actorIds.length);

      if (actorsResult.error || !Array.isArray(actorsResult.data)) {
        return {
          ok: false,
          message: sanitizeOrdersProviderError(actorsResult.error),
        };
      }

      for (const row of actorsResult.data) {
        if (!isRecord(row) || typeof row.id !== "string") {
          return { ok: false, message: ORDERS_LOAD_FAILURE_MESSAGE };
        }
        const name =
          typeof row.full_name === "string" && row.full_name.trim()
            ? row.full_name.trim()
            : "Staff";
        actorNameById.set(row.id, name);
      }
    }

    const history: OrderHistoryItem[] = historyRows.map((row) =>
      toHistoryItem(
        row,
        row.changed_by
          ? (actorNameById.get(row.changed_by) ?? "Staff")
          : "System",
      ),
    );

    return {
      ok: true,
      detail: buildOrderDetail({ order, items, history }),
    };
  } catch {
    return { ok: false, message: ORDERS_LOAD_FAILURE_MESSAGE };
  }
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null;
}
