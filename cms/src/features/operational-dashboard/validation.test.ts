import { describe, expect, it } from "vitest";

import {
  buildUtcDateSeries,
  getExpectedDailySeriesLength,
} from "@/features/operational-dashboard/series";
import {
  dashboardOverviewHref,
  parseDashboardQuery,
  parseDashboardRangeDays,
} from "@/features/operational-dashboard/validation";

describe("parseDashboardRangeDays", () => {
  it("clamps invalid values to the default 30-day window", () => {
    expect(parseDashboardRangeDays("14")).toBe(30);
    expect(parseDashboardRangeDays(undefined)).toBe(30);
  });

  it("accepts only exact 7, 30, or 90 strings", () => {
    expect(parseDashboardRangeDays("7")).toBe(7);
    expect(parseDashboardRangeDays("90")).toBe(90);
    expect(parseDashboardRangeDays("7abc")).toBe(30);
    expect(parseDashboardRangeDays("30days")).toBe(30);
  });
});

describe("parseDashboardQuery", () => {
  it("preserves only the validated range search param", () => {
    expect(
      parseDashboardQuery({
        range: "7",
        status: "pending",
        injected: "<script>",
      }),
    ).toEqual({ rangeDays: 7 });
  });
});

describe("dashboardOverviewHref", () => {
  it("omits the default range from the URL", () => {
    expect(dashboardOverviewHref({ rangeDays: 30 })).toBe("/dashboard");
    expect(dashboardOverviewHref({ rangeDays: 7 })).toBe("/dashboard?range=7");
  });
});

describe("series helpers", () => {
  it("builds consecutive UTC date series for range_days + 1", () => {
    expect(getExpectedDailySeriesLength(7)).toBe(8);
    expect(buildUtcDateSeries("2026-08-16", 8)).toEqual([
      "2026-08-16",
      "2026-08-17",
      "2026-08-18",
      "2026-08-19",
      "2026-08-20",
      "2026-08-21",
      "2026-08-22",
      "2026-08-23",
    ]);
  });
});
