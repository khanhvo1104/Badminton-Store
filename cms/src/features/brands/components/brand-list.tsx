import Link from "next/link";

import { EmptyState } from "@/components/ui/empty-state";
import { StatusBadge } from "@/components/ui/status-badge";
import { BrandPagination } from "@/features/brands/components/brand-pagination";
import { BRANDS_NEW_PATH, brandEditPath } from "@/features/brands/constants";
import type { BrandListResult } from "@/features/brands/types";

type BrandListProps = {
  result: BrandListResult;
};

export function BrandList({ result }: BrandListProps) {
  if (result.totalCount === 0) {
    return (
      <EmptyState
        title="No brands yet"
        description="Create the first brand to start organizing the catalog."
        action={
          <Link
            href={BRANDS_NEW_PATH}
            className="inline-flex rounded-full bg-emerald-300 px-5 py-3 text-sm font-semibold text-slate-950 transition hover:bg-emerald-200 focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-emerald-200"
          >
            Create brand
          </Link>
        }
      />
    );
  }

  return (
    <div className="space-y-6">
      <div className="overflow-x-auto rounded-3xl border border-white/10 bg-slate-900/60">
        <table className="min-w-full text-left text-sm text-slate-200">
          <thead className="border-b border-white/10 text-xs uppercase tracking-[0.2em] text-slate-400">
            <tr>
              <th scope="col" className="px-4 py-4 font-semibold">
                Brand
              </th>
              <th scope="col" className="px-4 py-4 font-semibold">
                Country
              </th>
              <th scope="col" className="px-4 py-4 font-semibold">
                Website
              </th>
              <th scope="col" className="px-4 py-4 font-semibold">
                Sort
              </th>
              <th scope="col" className="px-4 py-4 font-semibold">
                Status
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
                <td className="px-4 py-4 align-middle">
                  <div className="flex items-center gap-3">
                    {item.logoUrl ? (
                      // eslint-disable-next-line @next/next/no-img-element
                      <img
                        src={item.logoUrl}
                        alt=""
                        width={48}
                        height={48}
                        className="h-12 w-12 rounded-2xl object-contain"
                      />
                    ) : (
                      <div
                        aria-hidden="true"
                        className="flex h-12 w-12 items-center justify-center rounded-2xl border border-dashed border-white/15 bg-slate-950/50 text-xs text-slate-500"
                      >
                        —
                      </div>
                    )}
                    <div>
                      <p className="font-semibold text-white">{item.name}</p>
                      <p className="text-xs text-slate-400">{item.slug}</p>
                    </div>
                  </div>
                </td>
                <td className="px-4 py-4 align-middle text-slate-300">
                  {item.countryOfOrigin ?? "—"}
                </td>
                <td className="px-4 py-4 align-middle text-slate-300">
                  {item.websiteUrl?.toLowerCase().startsWith("https://") ? (
                    <a
                      href={item.websiteUrl}
                      className="font-semibold text-emerald-200 underline-offset-4 hover:underline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-emerald-200"
                    >
                      {item.websiteUrl}
                    </a>
                  ) : (
                    (item.websiteUrl ?? "—")
                  )}
                </td>
                <td className="px-4 py-4 align-middle text-slate-300">
                  {item.sortOrder}
                </td>
                <td className="px-4 py-4 align-middle">
                  <StatusBadge tone={item.isActive ? "success" : "neutral"}>
                    {item.isActive ? "Active" : "Inactive"}
                  </StatusBadge>
                </td>
                <td className="px-4 py-4 align-middle">
                  <Link
                    href={brandEditPath(item.id)}
                    className="font-semibold text-emerald-200 underline-offset-4 hover:underline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-emerald-200"
                  >
                    Edit
                  </Link>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      <BrandPagination result={result} />
    </div>
  );
}
