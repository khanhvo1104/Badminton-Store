"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { useEffect, useId, useRef, useState } from "react";

import {
  DASHBOARD_NAV_ITEMS,
  isDashboardNavCurrent,
  type DashboardNavItem,
} from "@/lib/navigation/dashboard-routes";

type DashboardNavigationProps = {
  items?: readonly DashboardNavItem[];
};

export function DashboardNavigation({
  items = DASHBOARD_NAV_ITEMS,
}: DashboardNavigationProps) {
  const pathname = usePathname() ?? "/dashboard";
  const [menuPath, setMenuPath] = useState<string | null>(null);
  const mobileOpen = menuPath === pathname;
  const menuButtonRef = useRef<HTMLButtonElement>(null);
  const panelId = useId();

  useEffect(() => {
    if (!mobileOpen) {
      return;
    }

    const handleKeyDown = (event: KeyboardEvent) => {
      if (event.key === "Escape") {
        setMenuPath(null);
        menuButtonRef.current?.focus();
      }
    };

    document.addEventListener("keydown", handleKeyDown);
    return () => document.removeEventListener("keydown", handleKeyDown);
  }, [mobileOpen]);

  return (
    <>
      <div className="hidden lg:block">
        <PrimaryNavList
          items={items}
          pathname={pathname}
          labelledBy="dashboard-desktop-nav-heading"
        />
      </div>

      <div className="lg:hidden">
        <button
          ref={menuButtonRef}
          type="button"
          aria-expanded={mobileOpen}
          aria-controls={panelId}
          onClick={() =>
            setMenuPath((current) => (current === pathname ? null : pathname))
          }
          className="inline-flex items-center rounded-full border border-white/15 px-4 py-2 text-sm font-semibold text-white transition hover:border-white/30 hover:bg-white/5 focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-emerald-200"
        >
          {mobileOpen ? "Close navigation" : "Open navigation"}
        </button>

        <div
          id={panelId}
          hidden={!mobileOpen}
          className="mt-4 rounded-3xl border border-white/10 bg-slate-950/95 p-4 shadow-2xl shadow-slate-950/40"
        >
          <PrimaryNavList
            items={items}
            pathname={pathname}
            labelledBy="dashboard-mobile-nav-heading"
            onNavigate={() => {
              setMenuPath(null);
              menuButtonRef.current?.focus();
            }}
          />
        </div>
      </div>
    </>
  );
}

type PrimaryNavListProps = {
  items: readonly DashboardNavItem[];
  pathname: string;
  labelledBy: string;
  onNavigate?: () => void;
};

function PrimaryNavList({
  items,
  pathname,
  labelledBy,
  onNavigate,
}: PrimaryNavListProps) {
  const heading =
    labelledBy === "dashboard-desktop-nav-heading"
      ? "Primary"
      : "Mobile primary";

  return (
    <nav aria-labelledby={labelledBy} className="space-y-3">
      <h2 id={labelledBy} className="sr-only">
        {heading} navigation
      </h2>
      <ul className="space-y-1">
        {items.map((item) => {
          const current = isDashboardNavCurrent(item.href, pathname);
          return (
            <li key={item.id}>
              <Link
                href={item.href}
                aria-current={current ? "page" : undefined}
                onClick={onNavigate}
                className={`block rounded-2xl px-4 py-3 text-sm font-medium transition focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-emerald-200 ${
                  current
                    ? "bg-emerald-300/15 text-emerald-100"
                    : "text-slate-200 hover:bg-white/5 hover:text-white"
                }`}
              >
                {item.label}
              </Link>
            </li>
          );
        })}
      </ul>
    </nav>
  );
}
