import Link from "next/link";
import { notFound } from "next/navigation";

import { ErrorState } from "@/components/ui/error-state";
import { ProductForm } from "@/features/products/components/product-form";
import { productFormStateFromValues } from "@/features/products/product-form-state";
import {
  PRODUCTS_LIST_PATH,
  productDetailPath,
} from "@/features/products/constants";
import {
  getProductById,
  listProductFormReferenceOptions,
  type ProductDetailQueryClient,
} from "@/features/products/detail-queries";
import { formatSpecificationsForForm } from "@/features/products/specifications";
import { productSuccessMessage } from "@/features/products/success-message";
import { toDatetimeLocalValue } from "@/features/products/form-validation";
import { isValidUuid } from "@/features/products/validation";
import { createSupabaseServerClient } from "@/lib/supabase/server";

export const dynamic = "force-dynamic";

type EditProductPageProps = {
  params: Promise<{ productId: string }>;
  searchParams?: Promise<Record<string, string | string[] | undefined>>;
};

export default async function EditProductPage({
  params,
  searchParams,
}: EditProductPageProps) {
  const { productId } = await params;
  const resolvedSearchParams = (await searchParams) ?? {};

  if (!isValidUuid(productId)) {
    notFound();
  }

  const supabase = await createSupabaseServerClient();
  const client = supabase as unknown as ProductDetailQueryClient;

  const productResult = await getProductById({ supabase: client, productId });

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
  const referenceOptions = await listProductFormReferenceOptions({
    supabase: client,
    includeCategoryIds: [product.categoryId],
    includeBrandIds: product.brandId ? [product.brandId] : [],
  });

  if (!referenceOptions.ok) {
    return (
      <div className="mx-auto max-w-3xl">
        <ErrorState
          title="Unable to load product form"
          description={referenceOptions.message}
        />
      </div>
    );
  }

  const successMessage = productSuccessMessage(resolvedSearchParams.success);
  const initialState = productFormStateFromValues({
    categoryId: product.categoryId,
    brandId: product.brandId ?? "",
    name: product.name,
    slug: product.slug,
    slugManual: true,
    shortDescription: product.shortDescription ?? "",
    description: product.description ?? "",
    specifications: formatSpecificationsForForm(product.specifications),
    searchKeywords: product.searchKeywords ?? "",
    status: product.status,
    isFeatured: product.isFeatured,
    publishedAt: toDatetimeLocalValue(product.publishedAt),
  });

  return (
    <div className="mx-auto max-w-3xl space-y-8">
      <header className="space-y-3">
        <p className="text-sm font-semibold uppercase tracking-[0.3em] text-emerald-300">
          Products
        </p>
        <h1 className="text-3xl font-semibold tracking-tight text-white sm:text-4xl">
          Edit product
        </h1>
        <p className="max-w-2xl text-base leading-7 text-slate-300">
          Update core fields for “{product.name}”.
        </p>
        <div className="flex flex-wrap gap-4 text-sm">
          <Link
            href={PRODUCTS_LIST_PATH}
            className="font-semibold text-emerald-200 underline-offset-4 hover:underline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-emerald-200"
          >
            Back to products
          </Link>
          <Link
            href={productDetailPath(product.id)}
            className="font-semibold text-emerald-200 underline-offset-4 hover:underline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-emerald-200"
          >
            View product
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

      <ProductForm
        mode="edit"
        productId={product.id}
        initialState={initialState}
        categories={referenceOptions.categories}
        brands={referenceOptions.brands}
      />
    </div>
  );
}
