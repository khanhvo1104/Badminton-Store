import { describe, expect, it } from "vitest";

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

  it("accepts only 7, 30, or 90", () => {
    expect(parseDashboardRangeDays("7")).toBe(7);
    expect(parseDashboardRangeDays("90")).toBe(90);
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
