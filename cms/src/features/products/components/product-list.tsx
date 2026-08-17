import Link from "next/link";

import { EmptyState } from "@/components/ui/empty-state";
import { StatusBadge } from "@/components/ui/status-badge";
import { ProductPagination } from "@/features/products/components/product-pagination";
import {
  PRODUCT_EDITOR_UNAVAILABLE_HELP,
  PRODUCT_EDITOR_UNAVAILABLE_LABEL,
  PRODUCTS_LIST_PATH,
} from "@/features/products/constants";
import type {
  ProductListItem,
  ProductListResult,
} from "@/features/products/types";
import { productExplorerHref } from "@/features/products/validation";

type ProductListProps = {
  result: ProductListResult;
};

export function ProductList({ result }: ProductListProps) {
  if (result.totalCount === 0 && result.pagination.page > 1) {
    return (
      <EmptyState
        title="No products on this page"
        description="This page is outside the current result set. Go back to the first page."
        action={
          <Link
            href={productExplorerHref({
              ...result.query,
              pagination: { page: 1, pageSize: result.pagination.pageSize },
            })}
            className="inline-flex rounded-full bg-emerald-300 px-5 py-3 text-sm font-semibold text-slate-950 transition hover:bg-emerald-200 focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-emerald-200"
          >
            Back to first page
          </Link>
        }
      />
    );
  }

  if (result.items.length === 0) {
    return (
      <EmptyState
        title={
          result.hasActiveFilters
            ? "No products match these filters"
            : "No products yet"
        }
        description={
          result.hasActiveFilters
            ? "Clear the search or filters to see more catalog products."
            : "Products created in later catalog tasks will appear here for staff review."
        }
        action={
          result.hasActiveFilters ? (
            <Link
              href={PRODUCTS_LIST_PATH}
              className="inline-flex rounded-full bg-emerald-300 px-5 py-3 text-sm font-semibold text-slate-950 transition hover:bg-emerald-200 focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-emerald-200"
            >
              Clear filters
            </Link>
          ) : null
        }
      />
    );
  }

  return (
    <div className="space-y-6">
      <div className="grid gap-4 lg:hidden">
        {result.items.map((item) => (
          <ProductCard key={item.id} item={item} />
        ))}
      </div>

      <div className="hidden overflow-x-auto rounded-3xl border border-white/10 bg-slate-900/60 lg:block">
        <table className="min-w-full text-left text-sm text-slate-200">
          <thead className="border-b border-white/10 text-xs uppercase tracking-[0.2em] text-slate-400">
            <tr>
              <th scope="col" className="px-4 py-4 font-semibold">
                Product
              </th>
              <th scope="col" className="px-4 py-4 font-semibold">
                Category
              </th>
              <th scope="col" className="px-4 py-4 font-semibold">
                Brand
              </th>
              <th scope="col" className="px-4 py-4 font-semibold">
                Status
              </th>
              <th scope="col" className="px-4 py-4 font-semibold">
                Variants
              </th>
              <th scope="col" className="px-4 py-4 font-semibold">
                Price
              </th>
              <th scope="col" className="px-4 py-4 font-semibold">
                Inventory
              </th>
              <th scope="col" className="px-4 py-4 font-semibold">
                Updated
              </th>
              <th scope="col" className="px-4 py-4 font-semibold">
                Actions
              </th>
            </tr>
          </thead>
          <tbody>
            {result.items.map((item) => (
              <tr
                key={item.id}
                className="border-b border-white/5 last:border-b-0"
              >
                <td className="px-4 py-4 align-top">
                  <div className="flex items-start gap-3">
                    <ProductImage url={item.primaryImageUrl} />
                    <div>
                      <p className="font-semibold text-white">{item.name}</p>
                      <p className="text-xs text-slate-400">{item.slug}</p>
                      <p className="mt-1 text-xs text-slate-400">
                        {item.featuredLabel}
                      </p>
                    </div>
                  </div>
                </td>
                <td className="px-4 py-4 align-top text-slate-300">
                  {item.categoryName ?? "Unknown category"}
                </td>
                <td className="px-4 py-4 align-top text-slate-300">
                  {item.brandName ?? "No brand"}
                </td>
                <td className="px-4 py-4 align-top">
                  <StatusBadge tone={statusTone(item.status)}>
                    {item.statusLabel}
                  </StatusBadge>
                </td>
                <td className="px-4 py-4 align-top text-slate-300">
                  {item.activeVariantCount}/{item.totalVariantCount}
                </td>
                <td className="px-4 py-4 align-top text-slate-300">
                  {item.priceRange.label}
                </td>
                <td className="px-4 py-4 align-top">
                  <InventorySummary item={item} />
                </td>
                <td className="px-4 py-4 align-top text-slate-300">
                  <p>{item.updatedAtLabel}</p>
                  <p className="text-xs text-slate-400">
                    Published {item.publishedAtLabel}
                  </p>
                </td>
                <td className="px-4 py-4 align-top">
                  <EditorAffordance />
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      <ProductPagination result={result} />
    </div>
  );
}

function ProductCard({ item }: { item: ProductListItem }) {
  return (
    <article className="space-y-4 rounded-3xl border border-white/10 bg-slate-900/60 p-5">
      <div className="flex items-start gap-3">
        <ProductImage url={item.primaryImageUrl} />
        <div>
          <h2 className="text-lg font-semibold text-white">{item.name}</h2>
          <p className="text-xs text-slate-400">{item.slug}</p>
        </div>
      </div>
      <dl className="grid gap-3 text-sm text-slate-300">
        <Info
          label="Category"
          value={item.categoryName ?? "Unknown category"}
        />
        <Info label="Brand" value={item.brandName ?? "No brand"} />
        <div>
          <dt className="text-xs uppercase tracking-[0.2em] text-slate-500">
            Status
          </dt>
          <dd className="mt-1">
            <StatusBadge tone={statusTone(item.status)}>
              {item.statusLabel}
            </StatusBadge>
            <span className="ml-2 text-slate-400">{item.featuredLabel}</span>
          </dd>
        </div>
        <Info
          label="Variants"
          value={`${item.activeVariantCount} active / ${item.totalVariantCount} total`}
        />
        <Info label="Price" value={item.priceRange.label} />
        <div>
          <dt className="text-xs uppercase tracking-[0.2em] text-slate-500">
            Inventory
          </dt>
          <dd className="mt-1">
            <InventorySummary item={item} />
          </dd>
        </div>
        <Info label="Updated" value={item.updatedAtLabel} />
        <Info label="Published" value={item.publishedAtLabel} />
      </dl>
      <EditorAffordance />
    </article>
  );
}

function InventorySummary({ item }: { item: ProductListItem }) {
  const { inventory } = item;
  const knownTotals =
    inventory.totalOnHand !== null &&
    inventory.totalReserved !== null &&
    inventory.totalAvailable !== null
      ? `On hand ${inventory.totalOnHand} · Reserved ${inventory.totalReserved} · Available ${inventory.totalAvailable}`
      : "On-hand, reserved, and available quantities are unknown.";

  return (
    <div className="space-y-1 text-sm text-slate-300">
      <p>{inventory.stockLabel}</p>
      <p className="text-xs text-slate-400">{knownTotals}</p>
      {inventory.hasMissingInventory ? (
        <p className="text-xs text-slate-400">
          {inventory.missingInventoryCount}{" "}
          {inventory.missingInventoryCount === 1 ? "variant" : "variants"}{" "}
          missing inventory.
        </p>
      ) : null}
    </div>
  );
}

function ProductImage({ url }: { url: string | null }) {
  if (url) {
    return (
      // eslint-disable-next-line @next/next/no-img-element
      <img
        src={url}
        alt=""
        width={48}
        height={48}
        className="h-12 w-12 rounded-2xl object-cover"
      />
    );
  }

  return (
    <div
      aria-hidden="true"
      className="flex h-12 w-12 items-center justify-center rounded-2xl border border-dashed border-white/15 bg-slate-950/50 text-xs text-slate-500"
    >
      —
    </div>
  );
}

function EditorAffordance() {
  return (
    <span
      aria-disabled="true"
      title={PRODUCT_EDITOR_UNAVAILABLE_HELP}
      className="inline-flex cursor-not-allowed rounded-full border border-white/10 px-3 py-1 text-sm text-slate-500"
    >
      {PRODUCT_EDITOR_UNAVAILABLE_LABEL}
    </span>
  );
}

function Info({ label, value }: { label: string; value: string }) {
  return (
    <div>
      <dt className="text-xs uppercase tracking-[0.2em] text-slate-500">
        {label}
      </dt>
      <dd className="mt-1">{value}</dd>
    </div>
  );
}

function statusTone(
  status: ProductListItem["status"],
): "success" | "neutral" | "danger" {
  if (status === "active") {
    return "success";
  }
  if (status === "archived") {
    return "danger";
  }
  return "neutral";
}
