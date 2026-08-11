"use client";

import { usePathname } from "next/navigation";

import { DashboardBreadcrumbs } from "@/components/layout/dashboard-breadcrumbs";

export function DashboardBreadcrumbsClient() {
  const pathname = usePathname() ?? "/dashboard";
  return <DashboardBreadcrumbs pathname={pathname} />;
}
