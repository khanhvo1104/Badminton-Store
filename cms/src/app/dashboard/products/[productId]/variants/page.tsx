import Link from "next/link";
import { notFound } from "next/navigation";

import { ErrorState } from "@/components/ui/error-state";
import {
  PRODUCTS_LIST_PATH,
  productDetailPath,
  productEditPath,
} from "@/features/products/constants";
import { isValidUuid } from "@/features/products/validation";
import { VariantList } from "@/features/variants/components/variant-list";
import { productVariantNewPath } from "@/features/variants/constants";
import {
  listProductVariants,
  type VariantQueryClient,
} from "@/features/variants/queries";
import { createSupabaseServerClient } from "@/lib/supabase/server";

export const dynamic = "force-dynamic";

type ProductVariantsPageProps = {
  params: Promise<{ productId: string }>;
};

export default async function ProductVariantsPage({
  params,
}: ProductVariantsPageProps) {
  const { productId } = await params;

  if (!isValidUuid(productId)) {
    notFound();
  }

  const supabase = await createSupabaseServerClient();
  const result = await listProductVariants({
    supabase: supabase as unknown as VariantQueryClient,
    productId,
  });

  if (!result.ok && result.notFound) {
    notFound();
  }

  if (!result.ok) {
    return (
      <div className="mx-auto max-w-6xl">
        <ErrorState
          title="Unable to load variants"
          description={result.message}
        />
      </div>
    );
  }

  const { data } = result;

  return (
    <div className="mx-auto max-w-6xl space-y-8">
      <header className="space-y-3">
        <p className="text-sm font-semibold uppercase tracking-[0.3em] text-emerald-300">
          Variants
        </p>
        <h1 className="text-3xl font-semibold tracking-tight text-white sm:text-4xl">
          Variants for {data.productName}
        </h1>
        <p className="max-w-3xl text-base leading-7 text-slate-300">
          Manage SKUs, attributes, selling prices, compare-at prices, and the
          protected cost contract for this product. Inventory, media, delete,
          and bulk import stay out of scope.
        </p>
        <div className="flex flex-wrap gap-4 text-sm">
          <Link
            href={PRODUCTS_LIST_PATH}
            className="font-semibold text-emerald-200 underline-offset-4 hover:underline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-emerald-200"
          >
            Back to products
          </Link>
          <Link
            href={productDetailPath(productId)}
            className="font-semibold text-emerald-200 underline-offset-4 hover:underline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-emerald-200"
          >
            View product
          </Link>
          <Link
            href={productEditPath(productId)}
            className="font-semibold text-emerald-200 underline-offset-4 hover:underline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-emerald-200"
          >
            Edit product
          </Link>
          <Link
            href={productVariantNewPath(productId)}
            className="font-semibold text-emerald-200 underline-offset-4 hover:underline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-emerald-200"
          >
            Add variant
          </Link>
        </div>
      </header>

      <VariantList productId={productId} variants={data.variants} />
    </div>
  );
}
