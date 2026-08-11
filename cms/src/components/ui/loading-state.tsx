type LoadingStateProps = {
  label?: string;
  className?: string;
};

export function LoadingState({
  label = "Loading content",
  className = "",
}: LoadingStateProps) {
  return (
    <div
      role="status"
      aria-live="polite"
      aria-busy="true"
      aria-label={label}
      className={`rounded-3xl border border-white/10 bg-slate-900/60 p-6 ${className}`.trim()}
    >
      <span className="sr-only">{label}</span>
      <div className="space-y-4" aria-hidden="true">
        <div className="h-4 w-1/3 animate-pulse rounded-full bg-white/10" />
        <div className="h-10 w-2/3 animate-pulse rounded-2xl bg-white/10" />
        <div className="h-24 w-full animate-pulse rounded-3xl bg-white/5" />
        <div className="grid gap-3 sm:grid-cols-2">
          <div className="h-20 animate-pulse rounded-2xl bg-white/5" />
          <div className="h-20 animate-pulse rounded-2xl bg-white/5" />
        </div>
      </div>
    </div>
  );
}
