import {
  DASHBOARD_AUTH_DENIED_MESSAGE,
  DASHBOARD_LOAD_FAILURE_MESSAGE,
  GET_CMS_OPERATIONAL_DASHBOARD_RPC,
} from "@/features/operational-dashboard/constants";
import { sanitizeDashboardProviderError } from "@/features/operational-dashboard/errors";
import {
  buildOperationalDashboardSnapshot,
  mapOperationalDashboardRpcRow,
} from "@/features/operational-dashboard/mappers";
import type {
  DashboardQuery,
  OperationalDashboardLoadResult,
} from "@/features/operational-dashboard/types";
import { getDashboardRpcArgs } from "@/features/operational-dashboard/validation";
import {
  type AuthorizationSupabaseClient,
  authorizeCmsRequest,
} from "@/lib/auth/authorization";

type QueryResponse = {
  data: unknown;
  error: unknown;
};

export type OperationalDashboardQueryClient = {
  auth: AuthorizationSupabaseClient["auth"];
  rpc: (
    fn: typeof GET_CMS_OPERATIONAL_DASHBOARD_RPC,
    args: ReturnType<typeof getDashboardRpcArgs>,
  ) => PromiseLike<QueryResponse>;
};

export async function getOperationalDashboard(options: {
  supabase: OperationalDashboardQueryClient;
  query: DashboardQuery;
}): Promise<OperationalDashboardLoadResult> {
  const { supabase, query } = options;

  try {
    const authorization = await authorizeCmsRequest(
      supabase as unknown as AuthorizationSupabaseClient,
    );
    if (authorization.kind !== "authorized") {
      return { ok: false, message: DASHBOARD_AUTH_DENIED_MESSAGE };
    }

    const { data, error } = await supabase.rpc(
      GET_CMS_OPERATIONAL_DASHBOARD_RPC,
      getDashboardRpcArgs(query),
    );

    if (error) {
      return { ok: false, message: sanitizeDashboardProviderError(error) };
    }

    const mapped = mapOperationalDashboardRpcRow(data);
    if (!mapped) {
      return { ok: false, message: DASHBOARD_LOAD_FAILURE_MESSAGE };
    }

    return {
      ok: true,
      snapshot: buildOperationalDashboardSnapshot(mapped),
    };
  } catch {
    return { ok: false, message: DASHBOARD_LOAD_FAILURE_MESSAGE };
  }
}
