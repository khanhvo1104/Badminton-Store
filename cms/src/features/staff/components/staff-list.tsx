import Link from "next/link";

import { EmptyState } from "@/components/ui/empty-state";
import { StatusBadge } from "@/components/ui/status-badge";
import { StaffMemberActions } from "@/features/staff/components/staff-member-actions";
import { StaffPagination } from "@/features/staff/components/staff-pagination";
import { STAFF_LIST_PATH } from "@/features/staff/constants";
import { getStaffDisplayName } from "@/features/staff/mappers";
import type { StaffListItem, StaffListResult } from "@/features/staff/types";
import { staffExplorerHref } from "@/features/staff/validation";

type StaffListProps = {
  result: StaffListResult;
  currentActorId: string;
};

export function StaffList({ result, currentActorId }: StaffListProps) {
  if (result.items.length === 0 && result.pagination.page > 1) {
    return (
      <EmptyState
        title="No staff on this page"
        description="This page is outside the current result set. Go back to the first page."
        action={
          <Link
            href={staffExplorerHref({
              ...result.query,
              pagination: { ...result.query.pagination, page: 1 },
            })}
            className="inline-flex rounded-full bg-emerald-300 px-5 py-3 text-sm font-semibold text-slate-950 transition hover:bg-emerald-200 focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-emerald-200"
          >
            Back to first page
          </Link>
        }
      />
    );
  }

  if (result.items.length === 0) {
    return (
      <EmptyState
        title={
          result.hasActiveFilters
            ? "No staff match these filters"
            : "No staff members yet"
        }
        description={
          result.hasActiveFilters
            ? "Clear the search or filters to see more staff members."
            : "Invite the first staff member to begin trusted CMS access."
        }
        action={
          result.hasActiveFilters ? (
            <Link
              href={STAFF_LIST_PATH}
              className="inline-flex rounded-full bg-emerald-300 px-5 py-3 text-sm font-semibold text-slate-950 transition hover:bg-emerald-200 focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-emerald-200"
            >
              Clear filters
            </Link>
          ) : null
        }
      />
    );
  }

  return (
    <div className="space-y-6">
      <div className="overflow-x-auto rounded-3xl border border-white/10 bg-slate-900/60">
        <table className="min-w-full text-left text-sm text-slate-200">
          <thead className="border-b border-white/10 text-xs uppercase tracking-[0.2em] text-slate-400">
            <tr>
              <th scope="col" className="px-4 py-4 font-semibold">
                Name
              </th>
              <th scope="col" className="px-4 py-4 font-semibold">
                Email
              </th>
              <th scope="col" className="px-4 py-4 font-semibold">
                Role
              </th>
              <th scope="col" className="px-4 py-4 font-semibold">
                Status
              </th>
              <th scope="col" className="px-4 py-4 font-semibold">
                Actions
              </th>
            </tr>
          </thead>
          <tbody className="divide-y divide-white/5">
            {result.items.map((item) => (
              <StaffRow
                key={item.profileId}
                item={item}
                currentActorId={currentActorId}
              />
            ))}
          </tbody>
        </table>
      </div>
      <StaffPagination result={result} />
    </div>
  );
}

function StaffRow({
  item,
  currentActorId,
}: {
  item: StaffListItem;
  currentActorId: string;
}) {
  const displayName = getStaffDisplayName(item);
  const isSelf = item.profileId === currentActorId;

  return (
    <tr>
      <td className="px-4 py-4 font-medium text-white">
        {displayName}
        {isSelf ? (
          <span className="ml-2 text-xs uppercase tracking-[0.2em] text-emerald-300">
            You
          </span>
        ) : null}
      </td>
      <td className="px-4 py-4 text-slate-300">{item.email}</td>
      <td className="px-4 py-4 capitalize text-slate-300">{item.role}</td>
      <td className="px-4 py-4">
        <StatusBadge tone={item.isActive ? "success" : "neutral"}>
          {item.isActive ? "Active" : "Inactive"}
        </StatusBadge>
      </td>
      <td className="px-4 py-4">
        <StaffMemberActions item={item} isSelf={isSelf} />
      </td>
    </tr>
  );
}
