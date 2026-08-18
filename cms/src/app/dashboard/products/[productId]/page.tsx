import Link from "next/link";
import { notFound } from "next/navigation";

import { ErrorState } from "@/components/ui/error-state";
import { ProductDetailView } from "@/features/products/components/product-detail-view";
import {
  PRODUCTS_LIST_PATH,
  productEditPath,
} from "@/features/products/constants";
import {
  getProductById,
  type ProductDetailQueryClient,
} from "@/features/products/detail-queries";
import { isValidUuid } from "@/features/products/validation";
import { createSupabaseServerClient } from "@/lib/supabase/server";

export const dynamic = "force-dynamic";

type ProductDetailPageProps = {
  params: Promise<{ productId: string }>;
};

export default async function ProductDetailPage({
  params,
}: ProductDetailPageProps) {
  const { productId } = await params;

  if (!isValidUuid(productId)) {
    notFound();
  }

  const supabase = await createSupabaseServerClient();
  const productResult = await getProductById({
    supabase: supabase as unknown as ProductDetailQueryClient,
    productId,
  });

  if (!productResult.ok && productResult.notFound) {
    notFound();
  }

  if (!productResult.ok) {
    return (
      <div className="mx-auto max-w-3xl">
        <ErrorState
          title="Unable to load product"
          description={productResult.message}
        />
      </div>
    );
  }

  const product = productResult.product;

  return (
    <div className="mx-auto max-w-3xl space-y-8">
      <header className="space-y-3">
        <p className="text-sm font-semibold uppercase tracking-[0.3em] text-emerald-300">
          Products
        </p>
        <h1 className="text-3xl font-semibold tracking-tight text-white sm:text-4xl">
          {product.name}
        </h1>
        <p className="max-w-2xl text-base leading-7 text-slate-300">
          Core product fields only. Variants, prices, inventory, and media are
          out of scope for this editor.
        </p>
        <div className="flex flex-wrap gap-4 text-sm">
          <Link
            href={PRODUCTS_LIST_PATH}
            className="font-semibold text-emerald-200 underline-offset-4 hover:underline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-emerald-200"
          >
            Back to products
          </Link>
          <Link
            href={productEditPath(product.id)}
            className="font-semibold text-emerald-200 underline-offset-4 hover:underline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-emerald-200"
          >
            Edit product
          </Link>
        </div>
      </header>

      <ProductDetailView product={product} />
    </div>
  );
}
