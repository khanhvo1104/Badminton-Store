import Link from "next/link";

import { EmptyState } from "@/components/ui/empty-state";
import { ErrorState } from "@/components/ui/error-state";
import { CategoryList } from "@/features/categories/components/category-list";
import { CATEGORIES_NEW_PATH } from "@/features/categories/constants";
import {
  listCategories,
  type CategoryListQueryClient,
  type CategoryNamesQueryClient,
} from "@/features/categories/queries";
import { categorySuccessMessage } from "@/features/categories/success-message";
import { parseCategoryPagination } from "@/features/categories/validation";
import { getPublicEnvironment } from "@/lib/env/public-env";
import { createSupabaseServerClient } from "@/lib/supabase/server";

export const dynamic = "force-dynamic";

type CategoriesPageProps = {
  searchParams?: Promise<Record<string, string | string[] | undefined>>;
};

export default async function CategoriesPage({
  searchParams,
}: CategoriesPageProps) {
  const resolvedSearchParams = (await searchParams) ?? {};
  const pagination = parseCategoryPagination(resolvedSearchParams);
  const successMessage = categorySuccessMessage(resolvedSearchParams.success);

  const environment = getPublicEnvironment();
  const supabase = await createSupabaseServerClient();
  const listed = await listCategories({
    supabase: supabase as unknown as CategoryListQueryClient &
      CategoryNamesQueryClient,
    pagination,
    supabaseUrl: environment.supabaseUrl,
  });

  return (
    <div className="mx-auto max-w-6xl space-y-8">
      <header className="flex flex-wrap items-end justify-between gap-4">
        <div className="space-y-3">
          <p className="text-sm font-semibold uppercase tracking-[0.3em] text-emerald-300">
            Categories
          </p>
          <h1 className="text-3xl font-semibold tracking-tight text-white sm:text-4xl">
            Category management
          </h1>
          <p className="max-w-3xl text-base leading-7 text-slate-300">
            Create, edit, order, and activate catalog categories. Inactive rows
            stay available to CMS staff and remain hidden from public readers.
          </p>
        </div>
        <Link
          href={CATEGORIES_NEW_PATH}
          className="inline-flex rounded-full bg-emerald-300 px-5 py-3 text-sm font-semibold text-slate-950 transition hover:bg-emerald-200 focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-emerald-200"
        >
          New category
        </Link>
      </header>

      {successMessage ? (
        <p
          role="status"
          aria-live="polite"
          className="rounded-3xl border border-emerald-300/20 bg-emerald-300/10 px-5 py-4 text-sm text-emerald-100"
        >
          {successMessage}
        </p>
      ) : null}

      {!listed.ok ? (
        <ErrorState
          title="Categories unavailable"
          description={listed.message}
        />
      ) : listed.result.totalCount === 0 &&
        listed.result.pagination.page > 1 ? (
        <EmptyState
          title="No categories on this page"
          description="This page is outside the current result set. Go back to the first page."
          action={
            <Link
              href="/dashboard/categories"
              className="inline-flex rounded-full bg-emerald-300 px-5 py-3 text-sm font-semibold text-slate-950 transition hover:bg-emerald-200 focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-emerald-200"
            >
              Back to first page
            </Link>
          }
        />
      ) : (
        <CategoryList result={listed.result} />
      )}
    </div>
  );
}
