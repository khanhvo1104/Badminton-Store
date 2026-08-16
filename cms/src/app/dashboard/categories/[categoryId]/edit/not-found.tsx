import Link from "next/link";

import { CATEGORIES_LIST_PATH } from "@/features/categories/constants";

export default function CategoryNotFound() {
  return (
    <div className="mx-auto max-w-2xl space-y-4 rounded-3xl border border-white/10 bg-slate-900/50 p-8">
      <h1 className="text-2xl font-semibold text-white">Category not found</h1>
      <p className="text-sm leading-7 text-slate-300">
        That category does not exist or is not available.
      </p>
      <Link
        href={CATEGORIES_LIST_PATH}
        className="inline-flex rounded-full bg-emerald-300 px-5 py-3 text-sm font-semibold text-slate-950 transition hover:bg-emerald-200 focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-emerald-200"
      >
        Back to categories
      </Link>
    </div>
  );
}
