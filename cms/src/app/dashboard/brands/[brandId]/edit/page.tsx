import Link from "next/link";
import { notFound } from "next/navigation";

import { ErrorState } from "@/components/ui/error-state";
import { BrandActivationForm } from "@/features/brands/components/brand-activation-form";
import { BrandForm } from "@/features/brands/components/brand-form";
import { brandFormStateFromValues } from "@/features/brands/brand-form-state";
import { BRANDS_LIST_PATH } from "@/features/brands/constants";
import {
  getBrandById,
  type BrandDetailQueryClient,
} from "@/features/brands/queries";
import { brandSuccessMessage } from "@/features/brands/success-message";
import { isValidUuid } from "@/features/brands/validation";
import { getPublicEnvironment } from "@/lib/env/public-env";
import { createSupabaseServerClient } from "@/lib/supabase/server";

export const dynamic = "force-dynamic";

type EditBrandPageProps = {
  params: Promise<{ brandId: string }>;
  searchParams?: Promise<Record<string, string | string[] | undefined>>;
};

export default async function EditBrandPage({
  params,
  searchParams,
}: EditBrandPageProps) {
  const { brandId } = await params;
  const resolvedSearchParams = (await searchParams) ?? {};

  if (!isValidUuid(brandId)) {
    notFound();
  }

  const environment = getPublicEnvironment();
  const supabase = await createSupabaseServerClient();
  const brandResult = await getBrandById({
    supabase: supabase as unknown as BrandDetailQueryClient,
    brandId,
    supabaseUrl: environment.supabaseUrl,
  });

  if (!brandResult.ok && brandResult.notFound) {
    notFound();
  }

  if (!brandResult.ok) {
    return (
      <div className="mx-auto max-w-3xl">
        <ErrorState
          title="Unable to load brand"
          description={brandResult.message}
        />
      </div>
    );
  }

  const brand = brandResult.brand;
  const successMessage = brandSuccessMessage(resolvedSearchParams.success);
  const initialState = brandFormStateFromValues({
    name: brand.name,
    slug: brand.slug,
    description: brand.description ?? "",
    websiteUrl: brand.websiteUrl ?? "",
    countryOfOrigin: brand.countryOfOrigin ?? "",
    sortOrder: String(brand.sortOrder),
    isActive: brand.isActive,
  });

  return (
    <div className="mx-auto max-w-3xl space-y-8">
      <header className="space-y-3">
        <p className="text-sm font-semibold uppercase tracking-[0.3em] text-emerald-300">
          Brands
        </p>
        <h1 className="text-3xl font-semibold tracking-tight text-white sm:text-4xl">
          Edit brand
        </h1>
        <p className="max-w-2xl text-base leading-7 text-slate-300">
          Update “{brand.name}”, including profile fields, activation, and logo.
        </p>
        <p>
          <Link
            href={BRANDS_LIST_PATH}
            className="text-sm font-semibold text-emerald-200 underline-offset-4 hover:underline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-emerald-200"
          >
            Back to brands
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

      <BrandForm
        mode="edit"
        brandId={brand.id}
        initialState={initialState}
        currentLogoUrl={brand.logoUrl}
      />

      <BrandActivationForm
        brandId={brand.id}
        isActive={brand.isActive}
        brandName={brand.name}
      />
    </div>
  );
}
