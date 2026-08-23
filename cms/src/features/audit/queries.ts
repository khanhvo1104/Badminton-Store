import {
  LIST_CMS_PRIVILEGED_AUDIT_RPC,
  AUDIT_AUTH_DENIED_MESSAGE,
  AUDIT_LOAD_FAILURE_MESSAGE,
} from "@/features/audit/constants";
import { sanitizeAuditProviderError } from "@/features/audit/errors";
import { mapAuditEventItem, mapCmsAuditRpcRow } from "@/features/audit/mappers";
import type {
  AuditExplorerLoadResult,
  AuditExplorerQuery,
} from "@/features/audit/types";
import {
  auditExplorerHasActiveFilters,
  getAuditExplorerRpcArgs,
} from "@/features/audit/validation";
import {
  type AuthorizationSupabaseClient,
  authorizeCmsAdminRequest,
} from "@/lib/auth/authorization";

type QueryResponse = {
  data: unknown;
  error: unknown;
};

export type AuditQueryClient = {
  auth: AuthorizationSupabaseClient["auth"];
  rpc: (
    fn: typeof LIST_CMS_PRIVILEGED_AUDIT_RPC,
    args: ReturnType<typeof getAuditExplorerRpcArgs>,
  ) => PromiseLike<QueryResponse>;
};

export async function listAuditEvents(options: {
  supabase: AuditQueryClient;
  query: AuditExplorerQuery;
}): Promise<AuditExplorerLoadResult> {
  const { supabase, query } = options;

  try {
    const authorization = await authorizeCmsAdminRequest(
      supabase as unknown as AuthorizationSupabaseClient,
    );
    if (authorization.kind !== "authorized") {
      return { ok: false, message: AUDIT_AUTH_DENIED_MESSAGE };
    }

    const { data, error } = await supabase.rpc(
      LIST_CMS_PRIVILEGED_AUDIT_RPC,
      getAuditExplorerRpcArgs(query),
    );

    if (error || !Array.isArray(data)) {
      return { ok: false, message: sanitizeAuditProviderError(error) };
    }

    const items = [];
    let hasMore = false;

    for (const row of data) {
      const rpcRow = mapCmsAuditRpcRow(row);
      if (!rpcRow) {
        return { ok: false, message: AUDIT_LOAD_FAILURE_MESSAGE };
      }

      if (typeof rpcRow.has_more === "boolean") {
        hasMore = rpcRow.has_more;
      }

      const mapped = mapAuditEventItem(rpcRow);
      if (!mapped) {
        return { ok: false, message: AUDIT_LOAD_FAILURE_MESSAGE };
      }
      items.push(mapped);
    }

    const lastItem = items.at(-1) ?? null;
    const nextCursor =
      hasMore && lastItem
        ? { occurredAt: lastItem.occurredAt, id: lastItem.eventId }
        : null;

    return {
      ok: true,
      result: {
        items,
        hasMore,
        nextCursor,
        query,
        hasActiveFilters: auditExplorerHasActiveFilters(query),
      },
    };
  } catch {
    return { ok: false, message: AUDIT_LOAD_FAILURE_MESSAGE };
  }
}
