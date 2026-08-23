import {
  DASHBOARD_DEFAULT_RANGE_DAYS,
  DASHBOARD_OVERVIEW_PATH,
  DASHBOARD_RANGE_DAYS,
} from "@/features/operational-dashboard/constants";
import type {
  DashboardQuery,
  DashboardRangeDays,
} from "@/features/operational-dashboard/types";

type SearchParamsInput =
  | Record<string, string | string[] | undefined>
  | URLSearchParams;

export function isDashboardRangeDays(
  value: unknown,
): value is DashboardRangeDays {
  return (
    typeof value === "number" &&
    (DASHBOARD_RANGE_DAYS as readonly number[]).includes(value)
  );
}

export function parseDashboardRangeDays(
  raw: string | undefined,
): DashboardRangeDays {
  const parsed = Number.parseInt((raw ?? "").trim(), 10);
  if (isDashboardRangeDays(parsed)) {
    return parsed;
  }
  return DASHBOARD_DEFAULT_RANGE_DAYS;
}

export function parseDashboardQuery(
  searchParams: SearchParamsInput,
): DashboardQuery {
  return {
    rangeDays: parseDashboardRangeDays(readSearchParam(searchParams, "range")),
  };
}

export function getDashboardRpcArgs(query: DashboardQuery) {
  return {
    p_range_days: query.rangeDays,
  };
}

export function dashboardOverviewHref(query: DashboardQuery): string {
  const params = new URLSearchParams();
  if (query.rangeDays !== DASHBOARD_DEFAULT_RANGE_DAYS) {
    params.set("range", String(query.rangeDays));
  }
  const queryString = params.toString();
  return queryString
    ? `${DASHBOARD_OVERVIEW_PATH}?${queryString}`
    : DASHBOARD_OVERVIEW_PATH;
}

function readSearchParam(
  searchParams: SearchParamsInput,
  key: string,
): string | undefined {
  if (searchParams instanceof URLSearchParams) {
    return searchParams.get(key) ?? undefined;
  }

  const value = searchParams[key];
  if (Array.isArray(value)) {
    return value[0];
  }
  return value;
}
