import Link from "next/link";
import { notFound } from "next/navigation";

import { ErrorState } from "@/components/ui/error-state";
import { ProductMediaManager } from "@/features/media/components/product-media-manager";
import {
  getProductMediaPage,
  type MediaQueryClient,
} from "@/features/media/queries";
import { mediaSuccessMessage } from "@/features/media/success-message";
import { isValidUuid } from "@/features/media/validation";
import {
  PRODUCTS_LIST_PATH,
  productDetailPath,
  productEditPath,
} from "@/features/products/constants";
import { productVariantsPath } from "@/features/variants/constants";
import { getPublicEnvironment } from "@/lib/env/public-env";
import { createSupabaseServerClient } from "@/lib/supabase/server";

export const dynamic = "force-dynamic";

type ProductMediaPageProps = {
  params: Promise<{ productId: string }>;
  searchParams?: Promise<Record<string, string | string[] | undefined>>;
};

export default async function ProductMediaPage({
  params,
  searchParams,
}: ProductMediaPageProps) {
  const { productId } = await params;
  const resolvedSearchParams = (await searchParams) ?? {};

  if (!isValidUuid(productId)) {
    notFound();
  }

  const environment = getPublicEnvironment();
  const supabase = await createSupabaseServerClient();
  const result = await getProductMediaPage({
    supabase: supabase as unknown as MediaQueryClient,
    productId,
    supabaseUrl: environment.supabaseUrl,
  });

  if (!result.ok && result.notFound) {
    notFound();
  }

  if (!result.ok) {
    return (
      <div className="mx-auto max-w-4xl">
        <ErrorState
          title="Unable to load product images"
          description={result.message}
        />
      </div>
    );
  }

  const successMessage = mediaSuccessMessage(resolvedSearchParams.success);

  return (
    <div className="mx-auto max-w-4xl space-y-8">
      <header className="space-y-3">
        <p className="text-sm font-semibold uppercase tracking-[0.3em] text-emerald-300">
          Product images
        </p>
        <h1 className="text-3xl font-semibold tracking-tight text-white sm:text-4xl">
          Media for {result.data.productName}
        </h1>
        <p className="max-w-3xl text-base leading-7 text-slate-300">
          Upload, order, replace, and delete catalog images for this product.
          Previews use stored object paths only and never inline SVG.
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
            href={productVariantsPath(productId)}
            className="font-semibold text-emerald-200 underline-offset-4 hover:underline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-emerald-200"
          >
            Manage variants
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

      <ProductMediaManager
        productId={result.data.productId}
        images={result.data.images}
        variants={result.data.variants}
      />
    </div>
  );
}
