import Link from "next/link";

import { EmptyState } from "@/components/ui/empty-state";
import { StatusBadge } from "@/components/ui/status-badge";
import {
  productVariantEditPath,
  productVariantNewPath,
} from "@/features/variants/constants";
import type { VariantListItem } from "@/features/variants/types";

type VariantListProps = {
  productId: string;
  variants: VariantListItem[];
};

export function VariantList({ productId, variants }: VariantListProps) {
  if (variants.length === 0) {
    return (
      <EmptyState
        title="No variants yet"
        description="Create the first SKU for this product. It will become the default variant."
        action={
          <Link
            href={productVariantNewPath(productId)}
            className="inline-flex rounded-full bg-emerald-300 px-5 py-3 text-sm font-semibold text-slate-950 transition hover:bg-emerald-200 focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-emerald-200"
          >
            Add variant
          </Link>
        }
      />
    );
  }

  return (
    <div className="space-y-6">
      <div className="grid gap-4 lg:hidden">
        {variants.map((item) => (
          <VariantCard key={item.id} item={item} productId={productId} />
        ))}
      </div>

      <div className="hidden overflow-x-auto rounded-3xl border border-white/10 bg-slate-900/60 lg:block">
        <table className="min-w-full text-left text-sm text-slate-200">
          <thead className="border-b border-white/10 text-xs uppercase tracking-[0.2em] text-slate-400">
            <tr>
              <th scope="col" className="px-4 py-4 font-semibold">
                Status
              </th>
              <th scope="col" className="px-4 py-4 font-semibold">
                SKU / name
              </th>
              <th scope="col" className="px-4 py-4 font-semibold">
                Attributes
              </th>
              <th scope="col" className="px-4 py-4 font-semibold">
                Selling price
              </th>
              <th scope="col" className="px-4 py-4 font-semibold">
                Compare-at
              </th>
              <th scope="col" className="px-4 py-4 font-semibold">
                Protected cost
              </th>
              <th scope="col" className="px-4 py-4 font-semibold">
                Unit
              </th>
              <th scope="col" className="px-4 py-4 font-semibold">
                Sort
              </th>
              <th scope="col" className="px-4 py-4 font-semibold">
                Actions
              </th>
            </tr>
          </thead>
          <tbody>
            {variants.map((item) => (
              <tr
                key={item.id}
                className="border-b border-white/5 last:border-b-0"
              >
                <td className="px-4 py-4 align-top">
                  <div className="flex flex-col gap-2">
                    <StatusBadge tone={item.isActive ? "success" : "neutral"}>
                      {item.statusLabel}
                    </StatusBadge>
                    <StatusBadge tone={item.isDefault ? "success" : "neutral"}>
                      {item.defaultLabel}
                    </StatusBadge>
                  </div>
                </td>
                <td className="px-4 py-4 align-top">
                  <p className="font-semibold text-white">{item.sku}</p>
                  <p className="text-xs text-slate-400">
                    {item.name ?? "No name"}
                  </p>
                </td>
                <td className="px-4 py-4 align-top text-slate-300">
                  {item.attributesLabel}
                </td>
                <td className="px-4 py-4 align-top text-slate-300">
                  {item.priceLabel}
                </td>
                <td className="px-4 py-4 align-top text-slate-300">
                  {item.compareAtPriceLabel}
                </td>
                <td className="px-4 py-4 align-top text-slate-300">
                  {item.costPriceLabel}
                </td>
                <td className="px-4 py-4 align-top text-slate-300">
                  {item.unit}
                </td>
                <td className="px-4 py-4 align-top text-slate-300">
                  {item.sortOrder}
                </td>
                <td className="px-4 py-4 align-top">
                  <Link
                    href={productVariantEditPath(productId, item.id)}
                    aria-label={`Edit variant ${item.sku}`}
                    className="inline-flex rounded-full bg-emerald-300 px-3 py-1 text-sm font-semibold text-slate-950 transition hover:bg-emerald-200 focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-emerald-200"
                  >
                    Edit
                  </Link>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );
}

function VariantCard({
  item,
  productId,
}: {
  item: VariantListItem;
  productId: string;
}) {
  return (
    <article className="space-y-4 rounded-3xl border border-white/10 bg-slate-900/60 p-5">
      <div>
        <h2 className="text-lg font-semibold text-white">{item.sku}</h2>
        <p className="text-xs text-slate-400">{item.name ?? "No name"}</p>
      </div>
      <div className="flex flex-wrap gap-2">
        <StatusBadge tone={item.isActive ? "success" : "neutral"}>
          {item.statusLabel}
        </StatusBadge>
        <StatusBadge tone={item.isDefault ? "success" : "neutral"}>
          {item.defaultLabel}
        </StatusBadge>
      </div>
      <dl className="grid gap-3 text-sm text-slate-300">
        <Info label="Attributes" value={item.attributesLabel} />
        <Info label="Selling price" value={item.priceLabel} />
        <Info label="Compare-at" value={item.compareAtPriceLabel} />
        <Info label="Protected cost" value={item.costPriceLabel} />
        <Info label="Unit" value={item.unit} />
        <Info label="Sort order" value={String(item.sortOrder)} />
      </dl>
      <Link
        href={productVariantEditPath(productId, item.id)}
        aria-label={`Edit variant ${item.sku}`}
        className="inline-flex rounded-full bg-emerald-300 px-3 py-1 text-sm font-semibold text-slate-950 transition hover:bg-emerald-200 focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-emerald-200"
      >
        Edit
      </Link>
    </article>
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
