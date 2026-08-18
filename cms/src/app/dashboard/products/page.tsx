import type { ReactNode } from "react";
import Link from "next/link";

import { ErrorState } from "@/components/ui/error-state";
import { ProductFilters } from "@/features/products/components/product-filters";
import { ProductList } from "@/features/products/components/product-list";
import {
  PRODUCT_AUTH_DENIED_MESSAGE,
  PRODUCTS_NEW_PATH,
} from "@/features/products/constants";
import {
  listProductBrandOptions,
  listProductCategoryOptions,
  listProducts,
  type ProductExplorerQueryClient,
} from "@/features/products/queries";
import { parseProductExplorerQuery } from "@/features/products/validation";
import {
  type AuthorizationSupabaseClient,
  authorizeCmsRequest,
} from "@/lib/auth/authorization";
import { getPublicEnvironment } from "@/lib/env/public-env";
import { createSupabaseServerClient } from "@/lib/supabase/server";

export const dynamic = "force-dynamic";

type ProductsPageProps = {
  searchParams?: Promise<Record<string, string | string[] | undefined>>;
};

export default async function ProductsPage({
  searchParams,
}: ProductsPageProps) {
  const resolvedSearchParams = (await searchParams) ?? {};
  const query = parseProductExplorerQuery(resolvedSearchParams);

  const environment = getPublicEnvironment();
  const supabase = await createSupabaseServerClient();
  const authorization = await authorizeCmsRequest(
    supabase as unknown as AuthorizationSupabaseClient,
  );

  if (authorization.kind !== "authorized") {
    return (
      <ProductExplorerShell>
        <ErrorState
          title="Products unavailable"
          description={PRODUCT_AUTH_DENIED_MESSAGE}
        />
      </ProductExplorerShell>
    );
  }

  const client = supabase as unknown as ProductExplorerQueryClient;
  const [listed, categories, brands] = await Promise.all([
    listProducts({
      supabase: client,
      query,
      supabaseUrl: environment.supabaseUrl,
    }),
    listProductCategoryOptions({ supabase: client }),
    listProductBrandOptions({ supabase: client }),
  ]);

  if (!categories.ok) {
    return (
      <ProductExplorerShell>
        <ErrorState
          title="Products unavailable"
          description={categories.message}
        />
      </ProductExplorerShell>
    );
  }

  if (!brands.ok) {
    return (
      <ProductExplorerShell>
        <ErrorState title="Products unavailable" description={brands.message} />
      </ProductExplorerShell>
    );
  }

  return (
    <ProductExplorerShell>
      <ProductFilters
        query={query}
        categories={categories.options}
        brands={brands.options}
      />
      {!listed.ok ? (
        <ErrorState title="Products unavailable" description={listed.message} />
      ) : (
        <ProductList result={listed.result} />
      )}
    </ProductExplorerShell>
  );
}

function ProductExplorerShell({ children }: { children: ReactNode }) {
  return (
    <div className="mx-auto max-w-6xl space-y-8">
      <header className="flex flex-wrap items-end justify-between gap-4">
        <div className="space-y-3">
          <p className="text-sm font-semibold uppercase tracking-[0.3em] text-emerald-300">
            Products
          </p>
          <h1 className="text-3xl font-semibold tracking-tight text-white sm:text-4xl">
            Product explorer
          </h1>
          <p className="max-w-3xl text-base leading-7 text-slate-300">
            Browse catalog products with server-side search, filters, sorting,
            and staff-safe inventory summaries. Create and edit core product
            fields without loading cost prices, variants, inventory, or media
            here.
          </p>
        </div>
        <Link
          href={PRODUCTS_NEW_PATH}
          className="inline-flex rounded-full bg-emerald-300 px-5 py-3 text-sm font-semibold text-slate-950 transition hover:bg-emerald-200 focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-emerald-200"
        >
          New product
        </Link>
      </header>
      {children}
    </div>
  );
}
