import type { ReactNode } from "react";

type EmptyStateProps = {
  title: string;
  description: string;
  action?: ReactNode;
  className?: string;
};

export function EmptyState({
  title,
  description,
  action,
  className = "",
}: EmptyStateProps) {
  return (
    <section
      aria-labelledby="empty-state-heading"
      className={`rounded-3xl border border-dashed border-white/15 bg-slate-900/50 p-8 sm:p-10 ${className}`.trim()}
    >
      <h2
        id="empty-state-heading"
        className="text-xl font-semibold tracking-tight text-white"
      >
        {title}
      </h2>
      <p className="mt-3 max-w-2xl text-sm leading-7 text-slate-300">
        {description}
      </p>
      {action ? <div className="mt-6">{action}</div> : null}
    </section>
  );
}
