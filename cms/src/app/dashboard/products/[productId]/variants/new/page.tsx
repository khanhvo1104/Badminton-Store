import Link from "next/link";
import { notFound } from "next/navigation";

import { ErrorState } from "@/components/ui/error-state";
import {
  productDetailPath,
  productEditPath,
} from "@/features/products/constants";
import { isValidUuid } from "@/features/products/validation";
import { VariantForm } from "@/features/variants/components/variant-form";
import { productVariantsPath } from "@/features/variants/constants";
import {
  listProductVariants,
  type VariantQueryClient,
} from "@/features/variants/queries";
import { createSupabaseServerClient } from "@/lib/supabase/server";

export const dynamic = "force-dynamic";

type NewVariantPageProps = {
  params: Promise<{ productId: string }>;
};

export default async function NewVariantPage({ params }: NewVariantPageProps) {
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
      <div className="mx-auto max-w-3xl">
        <ErrorState
          title="Unable to load variant form"
          description={result.message}
        />
      </div>
    );
  }

  return (
    <div className="mx-auto max-w-3xl space-y-8">
      <header className="space-y-3">
        <p className="text-sm font-semibold uppercase tracking-[0.3em] text-emerald-300">
          Variants
        </p>
        <h1 className="text-3xl font-semibold tracking-tight text-white sm:text-4xl">
          Create variant
        </h1>
        <p className="max-w-2xl text-base leading-7 text-slate-300">
          Add a SKU for “{result.data.productName}”.
          {result.data.isFirstVariant
            ? " This is the first variant, so it will become the default."
            : ""}
        </p>
        <div className="flex flex-wrap gap-4 text-sm">
          <Link
            href={productVariantsPath(productId)}
            className="font-semibold text-emerald-200 underline-offset-4 hover:underline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-emerald-200"
          >
            Back to variants
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
        </div>
      </header>

      <VariantForm
        mode="create"
        productId={productId}
        isFirstVariant={result.data.isFirstVariant}
      />
    </div>
  );
}
