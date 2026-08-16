import Link from "next/link";

import { CATEGORIES_LIST_PATH } from "@/features/categories/constants";
import type { CategoryListResult } from "@/features/categories/types";

type CategoryPaginationProps = {
  result: CategoryListResult;
};

export function CategoryPagination({ result }: CategoryPaginationProps) {
  const { pagination, totalCount, totalPages } = result;
  if (totalPages <= 1) {
    return (
      <p className="text-sm text-slate-400" aria-live="polite">
        Showing {totalCount} {totalCount === 1 ? "category" : "categories"}
      </p>
    );
  }

  const previousPage = pagination.page > 1 ? pagination.page - 1 : null;
  const nextPage = pagination.page < totalPages ? pagination.page + 1 : null;

  return (
    <nav
      aria-label="Category pagination"
      className="flex flex-wrap items-center justify-between gap-4"
    >
      <p className="text-sm text-slate-400" aria-live="polite">
        Page {pagination.page} of {totalPages} · {totalCount} total
      </p>
      <div className="flex gap-3">
        {previousPage ? (
          <Link
            href={buildPageHref(previousPage, pagination.pageSize)}
            className="rounded-full border border-white/15 px-4 py-2 text-sm font-semibold text-white transition hover:border-white/30 hover:bg-white/5 focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-emerald-200"
          >
            Previous
          </Link>
        ) : (
          <span className="rounded-full border border-white/10 px-4 py-2 text-sm text-slate-500">
            Previous
          </span>
        )}
        {nextPage ? (
          <Link
            href={buildPageHref(nextPage, pagination.pageSize)}
            className="rounded-full border border-white/15 px-4 py-2 text-sm font-semibold text-white transition hover:border-white/30 hover:bg-white/5 focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-emerald-200"
          >
            Next
          </Link>
        ) : (
          <span className="rounded-full border border-white/10 px-4 py-2 text-sm text-slate-500">
            Next
          </span>
        )}
      </div>
    </nav>
  );
}

function buildPageHref(page: number, pageSize: number): string {
  const params = new URLSearchParams();
  params.set("page", String(page));
  params.set("pageSize", String(pageSize));
  return `${CATEGORIES_LIST_PATH}?${params.toString()}`;
}
