import { describe, expect, it } from "vitest";

import {
  buildDashboardBreadcrumbs,
  getSafeDisplayName,
  getTrustedRoleLabel,
  isDashboardNavCurrent,
  normalizeDashboardPathname,
  UNKNOWN_ROUTE_LABEL,
} from "@/lib/navigation/dashboard-routes";

describe("dashboard routes", () => {
  it("normalizes trailing slashes and ignores query or hash fragments", () => {
    expect(normalizeDashboardPathname("/dashboard/categories/?q=1#x")).toBe(
      "/dashboard/categories",
    );
  });

  it("marks only exact overview current and nested children for sections", () => {
    expect(isDashboardNavCurrent("/dashboard", "/dashboard")).toBe(true);
    expect(isDashboardNavCurrent("/dashboard", "/dashboard/categories")).toBe(
      false,
    );
    expect(
      isDashboardNavCurrent(
        "/dashboard/categories",
        "/dashboard/categories/extra",
      ),
    ).toBe(true);
  });

  it("builds typed breadcrumbs and never echoes unknown segments", () => {
    expect(buildDashboardBreadcrumbs("/dashboard")).toEqual([
      { href: "/dashboard", label: "Overview", current: true },
    ]);

    expect(buildDashboardBreadcrumbs("/dashboard/products")).toEqual([
      { href: "/dashboard", label: "Overview", current: false },
      { href: "/dashboard/products", label: "Products", current: true },
    ]);

    expect(
      buildDashboardBreadcrumbs(
        "/dashboard/inventory/40000000-0000-4000-8000-000000000001",
      ),
    ).toEqual([
      { href: "/dashboard", label: "Overview", current: false },
      { href: "/dashboard/inventory", label: "Inventory", current: false },
      { label: UNKNOWN_ROUTE_LABEL, current: true },
    ]);

    expect(
      buildDashboardBreadcrumbs(
        "/dashboard/categories/%3Cscript%3Ealert(1)%3C/script%3E?next=/evil",
      ),
    ).toEqual([
      { href: "/dashboard", label: "Overview", current: false },
      { href: "/dashboard/categories", label: "Categories", current: false },
      { label: UNKNOWN_ROUTE_LABEL, current: true },
    ]);

    const crumbLabels = buildDashboardBreadcrumbs(
      "/dashboard/unknown-attacker-text",
    ).map((item) => item.label);
    expect(crumbLabels).toEqual(["Overview", UNKNOWN_ROUTE_LABEL]);
    expect(crumbLabels.join(" ")).not.toMatch(/unknown-attacker-text|evil/i);
  });

  it("uses safe display name and trusted role labels only", () => {
    expect(
      getSafeDisplayName({ fullName: "  Alex Coach  ", role: "staff" }),
    ).toBe("Alex Coach");
    expect(getSafeDisplayName({ fullName: null, role: "staff" })).toBe(
      "Staff member",
    );
    expect(getSafeDisplayName({ fullName: " ", role: "admin" })).toBe("Admin");
    expect(getTrustedRoleLabel("staff")).toBe("Staff");
    expect(getTrustedRoleLabel("admin")).toBe("Admin");
  });
});
