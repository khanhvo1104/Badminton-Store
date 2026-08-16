import Link from "next/link";

import { ErrorState } from "@/components/ui/error-state";
import { CategoryForm } from "@/features/categories/components/category-form";
import { INITIAL_CATEGORY_FORM_STATE } from "@/features/categories/category-form-state";
import { CATEGORIES_LIST_PATH } from "@/features/categories/constants";
import {
  listCategoryParentOptions,
  type CategoryParentOptionsQueryClient,
} from "@/features/categories/queries";
import { createSupabaseServerClient } from "@/lib/supabase/server";

export const dynamic = "force-dynamic";

export default async function NewCategoryPage() {
  const supabase = await createSupabaseServerClient();
  const parents = await listCategoryParentOptions({
    supabase: supabase as unknown as CategoryParentOptionsQueryClient,
  });

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

  return (
    <div className="mx-auto max-w-3xl space-y-8">
      <header className="space-y-3">
        <p className="text-sm font-semibold uppercase tracking-[0.3em] text-emerald-300">
          Categories
        </p>
        <h1 className="text-3xl font-semibold tracking-tight text-white sm:text-4xl">
          Create category
        </h1>
        <p className="max-w-2xl text-base leading-7 text-slate-300">
          Add a catalog category with optional hierarchy, image, and activation
          state.
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

      <CategoryForm
        mode="create"
        initialState={INITIAL_CATEGORY_FORM_STATE}
        parentOptions={parents.options}
      />
    </div>
  );
}
