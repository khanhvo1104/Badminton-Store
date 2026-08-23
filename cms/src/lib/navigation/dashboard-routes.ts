export const DASHBOARD_ROOT_PATH = "/dashboard";
export const UNKNOWN_ROUTE_LABEL = "Page";

export type DashboardNavItemId =
  | "overview"
  | "categories"
  | "brands"
  | "products"
  | "inventory"
  | "orders"
  | "staff"
  | "audit";

export type DashboardNavItem = {
  id: DashboardNavItemId;
  href: string;
  label: string;
  description: string;
  adminOnly?: boolean;
};

export const DASHBOARD_NAV_ITEMS: readonly DashboardNavItem[] = [
  {
    id: "overview",
    href: DASHBOARD_ROOT_PATH,
    label: "Overview",
    description:
      "Operational sales signals, low-stock alerts, and quick access to catalog areas.",
  },
  {
    id: "categories",
    href: `${DASHBOARD_ROOT_PATH}/categories`,
    label: "Categories",
    description: "Category management arrives in a later catalog task.",
  },
  {
    id: "brands",
    href: `${DASHBOARD_ROOT_PATH}/brands`,
    label: "Brands",
    description: "Brand management arrives in a later catalog task.",
  },
  {
    id: "products",
    href: `${DASHBOARD_ROOT_PATH}/products`,
    label: "Products",
    description:
      "Read-only product explorer with search, filters, and inventory summaries.",
  },
  {
    id: "inventory",
    href: `${DASHBOARD_ROOT_PATH}/inventory`,
    label: "Inventory",
    description:
      "Per-variant stock explorer with atomic adjustments and history.",
  },
  {
    id: "orders",
    href: `${DASHBOARD_ROOT_PATH}/orders`,
    label: "Orders",
    description:
      "Order search, detail, and trusted status transitions with inventory effects.",
  },
  {
    id: "staff",
    href: `${DASHBOARD_ROOT_PATH}/staff`,
    label: "Staff",
    description:
      "Admin-only invitations, activation, and trusted role management.",
    adminOnly: true,
  },
  {
    id: "audit",
    href: `${DASHBOARD_ROOT_PATH}/audit`,
    label: "Audit",
    description:
      "Admin-only immutable ledger of privileged CMS catalog, inventory, order, media, and staff changes.",
    adminOnly: true,
  },
] as const;

const ROUTE_BY_HREF = new Map(
  DASHBOARD_NAV_ITEMS.map((item) => [item.href, item] as const),
);

export type BreadcrumbItem = {
  href?: string;
  label: string;
  current: boolean;
};

export function normalizeDashboardPathname(pathname: string): string {
  const withoutQuery = pathname.split("?")[0] ?? pathname;
  const withoutHash = withoutQuery.split("#")[0] ?? withoutQuery;
  if (withoutHash.length > 1 && withoutHash.endsWith("/")) {
    return withoutHash.slice(0, -1);
  }
  return withoutHash || DASHBOARD_ROOT_PATH;
}

export function getDashboardNavItem(
  href: string,
): DashboardNavItem | undefined {
  return ROUTE_BY_HREF.get(normalizeDashboardPathname(href));
}

export function isDashboardNavCurrent(
  itemHref: string,
  pathname: string,
): boolean {
  const current = normalizeDashboardPathname(pathname);
  const target = normalizeDashboardPathname(itemHref);

  if (target === DASHBOARD_ROOT_PATH) {
    return current === DASHBOARD_ROOT_PATH;
  }

  return current === target || current.startsWith(`${target}/`);
}

export function buildDashboardBreadcrumbs(pathname: string): BreadcrumbItem[] {
  const current = normalizeDashboardPathname(pathname);

  if (!current.startsWith(DASHBOARD_ROOT_PATH)) {
    return [
      {
        label: UNKNOWN_ROUTE_LABEL,
        current: true,
      },
    ];
  }

  if (current === DASHBOARD_ROOT_PATH) {
    return [
      {
        href: DASHBOARD_ROOT_PATH,
        label: "Overview",
        current: true,
      },
    ];
  }

  const exact = getDashboardNavItem(current);
  if (exact && exact.id !== "overview") {
    return [
      {
        href: DASHBOARD_ROOT_PATH,
        label: "Overview",
        current: false,
      },
      {
        href: exact.href,
        label: exact.label,
        current: true,
      },
    ];
  }

  const parent = DASHBOARD_NAV_ITEMS.find(
    (item) => item.id !== "overview" && current.startsWith(`${item.href}/`),
  );

  if (parent) {
    return [
      {
        href: DASHBOARD_ROOT_PATH,
        label: "Overview",
        current: false,
      },
      {
        href: parent.href,
        label: parent.label,
        current: false,
      },
      {
        label: UNKNOWN_ROUTE_LABEL,
        current: true,
      },
    ];
  }

  return [
    {
      href: DASHBOARD_ROOT_PATH,
      label: "Overview",
      current: false,
    },
    {
      label: UNKNOWN_ROUTE_LABEL,
      current: true,
    },
  ];
}

export type SafeShellProfile = {
  fullName: string | null;
  role: "staff" | "admin";
};

export function getSafeDisplayName(profile: SafeShellProfile): string {
  const trimmed = profile.fullName?.trim();
  if (trimmed) {
    return trimmed;
  }

  return profile.role === "admin" ? "Admin" : "Staff member";
}

export function getDashboardNavItemsForRole(
  role: SafeShellProfile["role"],
): readonly DashboardNavItem[] {
  if (role === "admin") {
    return DASHBOARD_NAV_ITEMS;
  }

  return DASHBOARD_NAV_ITEMS.filter((item) => !item.adminOnly);
}

export function getTrustedRoleLabel(role: "staff" | "admin"): string {
  return role === "admin" ? "Admin" : "Staff";
}
