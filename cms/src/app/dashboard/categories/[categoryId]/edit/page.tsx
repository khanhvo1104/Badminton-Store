import Link from "next/link";
import { notFound } from "next/navigation";

import { ErrorState } from "@/components/ui/error-state";
import { CategoryActivationForm } from "@/features/categories/components/category-activation-form";
import { CategoryForm } from "@/features/categories/components/category-form";
import { categoryFormStateFromValues } from "@/features/categories/category-form-state";
import { CATEGORIES_LIST_PATH } from "@/features/categories/constants";
import {
  getCategoryById,
  listCategoryParentOptions,
  type CategoryDetailQueryClient,
  type CategoryParentOptionsQueryClient,
} from "@/features/categories/queries";
import { categorySuccessMessage } from "@/features/categories/success-message";
import { isValidUuid } from "@/features/categories/validation";
import { getPublicEnvironment } from "@/lib/env/public-env";
import { createSupabaseServerClient } from "@/lib/supabase/server";

export const dynamic = "force-dynamic";

type EditCategoryPageProps = {
  params: Promise<{ categoryId: string }>;
  searchParams?: Promise<Record<string, string | string[] | undefined>>;
};

export default async function EditCategoryPage({
  params,
  searchParams,
}: EditCategoryPageProps) {
  const { categoryId } = await params;
  const resolvedSearchParams = (await searchParams) ?? {};

  if (!isValidUuid(categoryId)) {
    notFound();
  }

  const environment = getPublicEnvironment();
  const supabase = await createSupabaseServerClient();
  const detailClient = supabase as unknown as CategoryDetailQueryClient;
  const parentClient = supabase as unknown as CategoryParentOptionsQueryClient;
  const [categoryResult, parents] = await Promise.all([
    getCategoryById({
      supabase: detailClient,
      categoryId,
      supabaseUrl: environment.supabaseUrl,
    }),
    listCategoryParentOptions({
      supabase: parentClient,
      excludeCategoryId: categoryId,
    }),
  ]);

  if (!categoryResult.ok && categoryResult.notFound) {
    notFound();
  }

  if (!categoryResult.ok) {
    return (
      <div className="mx-auto max-w-3xl">
        <ErrorState
          title="Unable to load category"
          description={categoryResult.message}
        />
      </div>
    );
  }

  if (!parents.ok) {
    return (
      <div className="mx-auto max-w-3xl">
        <ErrorState
          title="Unable to load category form"
          description={parents.message}
        />
      </div>
    );
  }

  const category = categoryResult.category;
  const successMessage = categorySuccessMessage(resolvedSearchParams.success);
  const initialState = categoryFormStateFromValues({
    name: category.name,
    slug: category.slug,
    description: category.description ?? "",
    parentId: category.parentId ?? "",
    sortOrder: String(category.sortOrder),
    isActive: category.isActive,
  });

  return (
    <div className="mx-auto max-w-3xl space-y-8">
      <header className="space-y-3">
        <p className="text-sm font-semibold uppercase tracking-[0.3em] text-emerald-300">
          Categories
        </p>
        <h1 className="text-3xl font-semibold tracking-tight text-white sm:text-4xl">
          Edit category
        </h1>
        <p className="max-w-2xl text-base leading-7 text-slate-300">
          Update “{category.name}”, including hierarchy, activation, and image.
        </p>
        <p>
          <Link
            href={CATEGORIES_LIST_PATH}
            className="text-sm font-semibold text-emerald-200 underline-offset-4 hover:underline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-emerald-200"
          >
            Back to categories
          </Link>
        </p>
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

      <CategoryForm
        mode="edit"
        categoryId={category.id}
        initialState={initialState}
        parentOptions={parents.options}
        currentImageUrl={category.imageUrl}
      />

      <CategoryActivationForm
        categoryId={category.id}
        isActive={category.isActive}
        categoryName={category.name}
      />
    </div>
  );
}
