import {
  LIST_CMS_STAFF_RPC,
  STAFF_AUTH_DENIED_MESSAGE,
  STAFF_LOAD_FAILURE_MESSAGE,
} from "@/features/staff/constants";
import { sanitizeStaffProviderError } from "@/features/staff/errors";
import { mapCmsStaffRpcRow, mapStaffListItem } from "@/features/staff/mappers";
import type {
  StaffExplorerLoadResult,
  StaffExplorerQuery,
  StaffListItem,
} from "@/features/staff/types";
import {
  getStaffExplorerRpcArgs,
  staffExplorerHasActiveFilters,
} from "@/features/staff/validation";
import {
  type AuthorizationSupabaseClient,
  authorizeCmsAdminRequest,
} from "@/lib/auth/authorization";

type QueryResponse = {
  data: unknown;
  error: unknown;
};

export type StaffQueryClient = {
  auth: AuthorizationSupabaseClient["auth"];
  rpc: (
    fn: typeof LIST_CMS_STAFF_RPC,
    args: ReturnType<typeof getStaffExplorerRpcArgs>,
  ) => PromiseLike<QueryResponse>;
};

export async function listStaffMembers(options: {
  supabase: StaffQueryClient;
  query: StaffExplorerQuery;
}): Promise<StaffExplorerLoadResult> {
  const { supabase, query } = options;

  try {
    const authorization = await authorizeCmsAdminRequest(
      supabase as unknown as AuthorizationSupabaseClient,
    );
    if (authorization.kind !== "authorized") {
      return { ok: false, message: STAFF_AUTH_DENIED_MESSAGE };
    }

    const { data, error } = await supabase.rpc(
      LIST_CMS_STAFF_RPC,
      getStaffExplorerRpcArgs(query),
    );

    if (error || !Array.isArray(data)) {
      return { ok: false, message: sanitizeStaffProviderError(error) };
    }

    const rpcRows = [];
    for (const row of data) {
      const mapped = mapCmsStaffRpcRow(row);
      if (!mapped) {
        return { ok: false, message: STAFF_LOAD_FAILURE_MESSAGE };
      }
      rpcRows.push(mapped);
    }

    const totalCount = rpcRows[0]?.filtered_count ?? 0;
    const items: StaffListItem[] = [];
    for (const row of rpcRows) {
      if (row.profile_id === null || row.email === null) {
        continue;
      }
      const mapped = mapStaffListItem({
        ...row,
        profile_id: row.profile_id,
        email: row.email,
      });
      if (!mapped) {
        return { ok: false, message: STAFF_LOAD_FAILURE_MESSAGE };
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
        hasActiveFilters: staffExplorerHasActiveFilters(query),
      },
    };
  } catch {
    return { ok: false, message: STAFF_LOAD_FAILURE_MESSAGE };
  }
}
