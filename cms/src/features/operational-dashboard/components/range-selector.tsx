import Link from "next/link";

import {
  DASHBOARD_DEFAULT_RANGE_DAYS,
  DASHBOARD_RANGE_DAYS,
} from "@/features/operational-dashboard/constants";
import type { DashboardQuery } from "@/features/operational-dashboard/types";
import { dashboardOverviewHref } from "@/features/operational-dashboard/validation";

type DashboardRangeSelectorProps = {
  query: DashboardQuery;
};

export function DashboardRangeSelector({ query }: DashboardRangeSelectorProps) {
  return (
    <nav aria-label="Dashboard time range" className="flex flex-wrap gap-2">
      {DASHBOARD_RANGE_DAYS.map((rangeDays) => {
        const isCurrent = query.rangeDays === rangeDays;
        return (
          <Link
            key={rangeDays}
            href={dashboardOverviewHref({ rangeDays })}
            aria-current={isCurrent ? "page" : undefined}
            className={`rounded-full px-4 py-2 text-sm font-medium transition focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-emerald-200 ${
              isCurrent
                ? "bg-emerald-400 text-slate-950"
                : "border border-white/10 bg-slate-900/70 text-slate-200 hover:border-emerald-300/40 hover:text-white"
            }`}
          >
            Last {rangeDays} days
            {rangeDays === DASHBOARD_DEFAULT_RANGE_DAYS ? " (default)" : ""}
          </Link>
        );
      })}
    </nav>
  );
}
