import Link from "next/link";

import {
  buildDashboardBreadcrumbs,
  type BreadcrumbItem,
} from "@/lib/navigation/dashboard-routes";

type DashboardBreadcrumbsProps = {
  pathname: string;
};

export function DashboardBreadcrumbs({ pathname }: DashboardBreadcrumbsProps) {
  const items = buildDashboardBreadcrumbs(pathname);
  return <BreadcrumbList items={items} />;
}

export function BreadcrumbList({ items }: { items: BreadcrumbItem[] }) {
  return (
    <nav aria-label="Breadcrumb" className="min-w-0">
      <ol className="flex flex-wrap items-center gap-2 text-sm text-slate-300">
        {items.map((item, index) => {
          const isLast = index === items.length - 1;
          return (
            <li
              key={`${item.label}-${index}`}
              className="flex items-center gap-2"
            >
              {index > 0 ? (
                <span aria-hidden="true" className="text-slate-500">
                  /
                </span>
              ) : null}
              {item.current || !item.href || isLast ? (
                <span
                  aria-current={item.current ? "page" : undefined}
                  className={
                    item.current ? "font-medium text-white" : "text-slate-300"
                  }
                >
                  {item.label}
                </span>
              ) : (
                <Link
                  href={item.href}
                  className="rounded-sm transition hover:text-white focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-emerald-200"
                >
                  {item.label}
                </Link>
              )}
            </li>
          );
        })}
      </ol>
    </nav>
  );
}
