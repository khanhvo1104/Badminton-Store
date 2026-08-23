import Link from "next/link";

import type { StaffListResult } from "@/features/staff/types";
import { staffExplorerHref } from "@/features/staff/validation";

type StaffPaginationProps = {
  result: StaffListResult;
};

export function StaffPagination({ result }: StaffPaginationProps) {
  const { pagination, totalPages, totalCount } = result;

  if (totalPages <= 1) {
    return (
      <p className="text-sm text-slate-400">
        Showing {result.items.length} of {totalCount} staff members
      </p>
    );
  }

  const previousPage = pagination.page > 1 ? pagination.page - 1 : null;
  const nextPage = pagination.page < totalPages ? pagination.page + 1 : null;

  return (
    <div className="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
      <p className="text-sm text-slate-400">
        Page {pagination.page} of {totalPages} · {totalCount} staff members
      </p>
      <div className="flex gap-3">
        {previousPage ? (
          <Link
            href={staffExplorerHref({
              ...result.query,
              pagination: { ...pagination, page: previousPage },
            })}
            className="inline-flex rounded-full border border-white/15 px-4 py-2 text-sm font-semibold text-white transition hover:border-white/30 hover:bg-white/5 focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-emerald-200"
          >
            Previous
          </Link>
        ) : null}
        {nextPage ? (
          <Link
            href={staffExplorerHref({
              ...result.query,
              pagination: { ...pagination, page: nextPage },
            })}
            className="inline-flex rounded-full border border-white/15 px-4 py-2 text-sm font-semibold text-white transition hover:border-white/30 hover:bg-white/5 focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-emerald-200"
          >
            Next
          </Link>
        ) : null}
      </div>
    </div>
  );
}
