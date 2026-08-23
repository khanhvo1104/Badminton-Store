import Link from "next/link";

import type { ReactNode } from "react";

import {
  STAFF_ACTIVE_FILTERS,
  STAFF_LIST_PATH,
  STAFF_ROLE_FILTERS,
  STAFF_SORTS,
} from "@/features/staff/constants";
import type { StaffExplorerQuery } from "@/features/staff/types";
import { staffExplorerHasActiveFilters } from "@/features/staff/validation";

const ROLE_LABELS: Record<(typeof STAFF_ROLE_FILTERS)[number], string> = {
  all: "All roles",
  staff: "Staff",
  admin: "Admin",
};

const ACTIVE_LABELS: Record<(typeof STAFF_ACTIVE_FILTERS)[number], string> = {
  all: "All statuses",
  active: "Active",
  inactive: "Inactive",
};

const SORT_LABELS: Record<(typeof STAFF_SORTS)[number], string> = {
  name_asc: "Name A–Z",
  name_desc: "Name Z–A",
  created_desc: "Newest first",
  created_asc: "Oldest first",
  role_asc: "Role",
};

type StaffFiltersProps = {
  query: StaffExplorerQuery;
};

export function StaffFilters({ query }: StaffFiltersProps) {
  const hasActiveFilters = staffExplorerHasActiveFilters(query);

  return (
    <form
      method="get"
      action={STAFF_LIST_PATH}
      className="space-y-4 rounded-3xl border border-white/10 bg-slate-900/60 p-5"
      role="search"
      aria-label="Filter staff members"
    >
      <div className="grid gap-4 md:grid-cols-2 xl:grid-cols-4">
        <Field id="q" label="Search">
          <input
            id="q"
            name="q"
            type="search"
            defaultValue={query.search}
            maxLength={80}
            placeholder="Name or email"
            className={inputClassName}
          />
        </Field>
        <Field id="role" label="Role">
          <select
            id="role"
            name="role"
            defaultValue={query.role}
            className={inputClassName}
          >
            {STAFF_ROLE_FILTERS.map((role) => (
              <option key={role} value={role}>
                {ROLE_LABELS[role]}
              </option>
            ))}
          </select>
        </Field>
        <Field id="active" label="Status">
          <select
            id="active"
            name="active"
            defaultValue={query.active}
            className={inputClassName}
          >
            {STAFF_ACTIVE_FILTERS.map((active) => (
              <option key={active} value={active}>
                {ACTIVE_LABELS[active]}
              </option>
            ))}
          </select>
        </Field>
        <Field id="sort" label="Sort">
          <select
            id="sort"
            name="sort"
            defaultValue={query.sort}
            className={inputClassName}
          >
            {STAFF_SORTS.map((sort) => (
              <option key={sort} value={sort}>
                {SORT_LABELS[sort]}
              </option>
            ))}
          </select>
        </Field>
      </div>

      <div className="flex flex-wrap gap-3">
        <button
          type="submit"
          className="inline-flex rounded-full bg-emerald-300 px-5 py-3 text-sm font-semibold text-slate-950 transition hover:bg-emerald-200 focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-emerald-200"
        >
          Apply filters
        </button>
        {hasActiveFilters ? (
          <Link
            href={STAFF_LIST_PATH}
            className="inline-flex rounded-full border border-white/15 px-5 py-3 text-sm font-semibold text-white transition hover:border-white/30 hover:bg-white/5 focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-emerald-200"
          >
            Clear filters
          </Link>
        ) : null}
      </div>
    </form>
  );
}

function Field({
  id,
  label,
  children,
}: {
  id: string;
  label: string;
  children: ReactNode;
}) {
  return (
    <div className="space-y-2">
      <label htmlFor={id} className="text-sm font-medium text-slate-200">
        {label}
      </label>
      {children}
    </div>
  );
}

const inputClassName =
  "w-full rounded-2xl border border-white/10 bg-slate-950/80 px-4 py-3 text-sm text-white placeholder:text-slate-500 focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-emerald-200";
