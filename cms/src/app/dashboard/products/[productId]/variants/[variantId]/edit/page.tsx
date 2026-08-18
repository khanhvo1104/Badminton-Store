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
import { variantFormStateFromValues } from "@/features/variants/variant-form-state";
import { variantFormValuesFromItem } from "@/features/variants/mappers";
import {
  getProductVariant,
  type VariantQueryClient,
} from "@/features/variants/queries";
import { variantSuccessMessage } from "@/features/variants/success-message";
import { createSupabaseServerClient } from "@/lib/supabase/server";

export const dynamic = "force-dynamic";

type EditVariantPageProps = {
  params: Promise<{ productId: string; variantId: string }>;
  searchParams?: Promise<Record<string, string | string[] | undefined>>;
};

export default async function EditVariantPage({
  params,
  searchParams,
}: EditVariantPageProps) {
  const { productId, variantId } = await params;
  const resolvedSearchParams = (await searchParams) ?? {};

  if (!isValidUuid(productId) || !isValidUuid(variantId)) {
    notFound();
  }

  const supabase = await createSupabaseServerClient();
  const result = await getProductVariant({
    supabase: supabase as unknown as VariantQueryClient,
    productId,
    variantId,
  });

  if (!result.ok && result.notFound) {
    notFound();
  }

  if (!result.ok) {
    return (
      <div className="mx-auto max-w-3xl">
        <ErrorState
          title="Unable to load variant"
          description={result.message}
        />
      </div>
    );
  }

  const successMessage = variantSuccessMessage(resolvedSearchParams.success);

  return (
    <div className="mx-auto max-w-3xl space-y-8">
      <header className="space-y-3">
        <p className="text-sm font-semibold uppercase tracking-[0.3em] text-emerald-300">
          Variants
        </p>
        <h1 className="text-3xl font-semibold tracking-tight text-white sm:text-4xl">
          Edit variant
        </h1>
        <p className="max-w-2xl text-base leading-7 text-slate-300">
          Update SKU {result.variant.sku} for “{result.data.productName}”.
          Barcode cannot be shown; leave that field blank to keep the stored
          value.
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

      {successMessage ? (
        <p
          role="status"
          aria-live="polite"
          className="rounded-3xl border border-emerald-300/20 bg-emerald-300/10 px-5 py-4 text-sm text-emerald-100"
        >
          {successMessage}
        </p>
      ) : null}

      <VariantForm
        mode="edit"
        productId={productId}
        variantId={variantId}
        currentIsDefault={result.variant.isDefault}
        initialState={variantFormStateFromValues(
          variantFormValuesFromItem(result.variant),
        )}
      />
    </div>
  );
}
