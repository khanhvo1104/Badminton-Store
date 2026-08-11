import { EmptyState } from "@/components/ui/empty-state";

type PlaceholderPageProps = {
  eyebrow: string;
  title: string;
  description: string;
  emptyTitle: string;
  emptyDescription: string;
};

export function CatalogPlaceholderPage({
  eyebrow,
  title,
  description,
  emptyTitle,
  emptyDescription,
}: PlaceholderPageProps) {
  return (
    <div className="mx-auto max-w-4xl space-y-8">
      <header className="space-y-3">
        <p className="text-sm font-semibold uppercase tracking-[0.3em] text-emerald-300">
          {eyebrow}
        </p>
        <h1 className="text-3xl font-semibold tracking-tight text-white sm:text-4xl">
          {title}
        </h1>
        <p className="max-w-3xl text-base leading-7 text-slate-300">
          {description}
        </p>
      </header>

      <EmptyState title={emptyTitle} description={emptyDescription} />
    </div>
  );
}
