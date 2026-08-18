import Link from "next/link";

import { ProductForm } from "@/features/products/components/product-form";
import { INITIAL_PRODUCT_FORM_STATE } from "@/features/products/product-form-state";
import { PRODUCTS_LIST_PATH } from "@/features/products/constants";
import {
  listProductFormReferenceOptions,
  type ProductDetailQueryClient,
} from "@/features/products/detail-queries";
import { ErrorState } from "@/components/ui/error-state";
import { createSupabaseServerClient } from "@/lib/supabase/server";

export const dynamic = "force-dynamic";

export default async function NewProductPage() {
  const supabase = await createSupabaseServerClient();
  const references = await listProductFormReferenceOptions({
    supabase: supabase as unknown as ProductDetailQueryClient,
  });

  if (!references.ok) {
    return (
      <div className="mx-auto max-w-3xl">
        <ErrorState
          title="Unable to load product form"
          description={references.message}
        />
      </div>
    );
  }

  return (
    <div className="mx-auto max-w-3xl space-y-8">
      <header className="space-y-3">
        <p className="text-sm font-semibold uppercase tracking-[0.3em] text-emerald-300">
          Products
        </p>
        <h1 className="text-3xl font-semibold tracking-tight text-white sm:text-4xl">
          Create product
        </h1>
        <p className="max-w-2xl text-base leading-7 text-slate-300">
          Add core catalog fields for a new product. After saving, manage SKUs
          and prices from the product variant editor. Inventory and media arrive
          in later tasks.
        </p>
        <p>
          <Link
            href={PRODUCTS_LIST_PATH}
            className="text-sm font-semibold text-emerald-200 underline-offset-4 hover:underline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-emerald-200"
          >
            Back to products
          </Link>
        </p>
      </header>

      <ProductForm
        mode="create"
        initialState={INITIAL_PRODUCT_FORM_STATE}
        categories={references.categories}
        brands={references.brands}
      />
    </div>
  );
}
