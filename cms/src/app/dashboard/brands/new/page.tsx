import Link from "next/link";

import { BrandForm } from "@/features/brands/components/brand-form";
import { INITIAL_BRAND_FORM_STATE } from "@/features/brands/brand-form-state";
import { BRANDS_LIST_PATH } from "@/features/brands/constants";

export const dynamic = "force-dynamic";

export default function NewBrandPage() {
  return (
    <div className="mx-auto max-w-3xl space-y-8">
      <header className="space-y-3">
        <p className="text-sm font-semibold uppercase tracking-[0.3em] text-emerald-300">
          Brands
        </p>
        <h1 className="text-3xl font-semibold tracking-tight text-white sm:text-4xl">
          Create brand
        </h1>
        <p className="max-w-2xl text-base leading-7 text-slate-300">
          Add a catalog brand with optional website, country, logo, and
          activation state.
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

      <BrandForm mode="create" initialState={INITIAL_BRAND_FORM_STATE} />
    </div>
  );
}
