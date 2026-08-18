import { StatusBadge } from "@/components/ui/status-badge";
import type { ProductDetail } from "@/features/products/types";

type ProductDetailViewProps = {
  product: ProductDetail;
};

export function ProductDetailView({ product }: ProductDetailViewProps) {
  return (
    <dl className="grid gap-6 rounded-3xl border border-white/10 bg-slate-900/60 p-6 text-sm text-slate-200">
      <DetailItem label="Name" value={product.name} />
      <DetailItem label="Slug" value={product.slug} />
      <DetailItem
        label="Category"
        value={product.categoryName ?? "Unknown category"}
      />
      <DetailItem label="Brand" value={product.brandName ?? "No brand"} />
      <div>
        <dt className="text-xs uppercase tracking-[0.2em] text-slate-500">
          Status
        </dt>
        <dd className="mt-2 flex flex-wrap items-center gap-2">
          <StatusBadge tone={statusTone(product.status)}>
            {product.statusLabel}
          </StatusBadge>
          <span className="text-slate-300">{product.featuredLabel}</span>
        </dd>
      </div>
      <DetailItem label="Published" value={product.publishedAtLabel} />
      <DetailItem label="Updated" value={product.updatedAtLabel} />
      <DetailItem
        label="Short description"
        value={product.shortDescription ?? "None"}
      />
      <DetailItem
        label="Description"
        value={product.description ?? "None"}
        preserveWhitespace
      />
      <DetailItem
        label="Search keywords"
        value={product.searchKeywords ?? "None"}
      />
      <div>
        <dt className="text-xs uppercase tracking-[0.2em] text-slate-500">
          Specifications
        </dt>
        <dd className="mt-2">
          {Object.keys(product.specifications).length === 0 ? (
            <span>None</span>
          ) : (
            <pre className="overflow-x-auto rounded-2xl border border-white/10 bg-slate-950/70 p-4 font-mono text-xs text-slate-100">
              {JSON.stringify(product.specifications, null, 2)}
            </pre>
          )}
        </dd>
      </div>
    </dl>
  );
}

function DetailItem({
  label,
  value,
  preserveWhitespace = false,
}: {
  label: string;
  value: string;
  preserveWhitespace?: boolean;
}) {
  return (
    <div>
      <dt className="text-xs uppercase tracking-[0.2em] text-slate-500">
        {label}
      </dt>
      <dd
        className={`mt-2 text-slate-100 ${preserveWhitespace ? "whitespace-pre-wrap" : ""}`}
      >
        {value}
      </dd>
    </div>
  );
}

function statusTone(
  status: ProductDetail["status"],
): "success" | "neutral" | "danger" {
  if (status === "active") {
    return "success";
  }
  if (status === "archived") {
    return "danger";
  }
  return "neutral";
}
