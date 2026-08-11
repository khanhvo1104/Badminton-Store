"use client";

import { toUserFacingError } from "@/lib/errors/to-user-facing-error";

type ErrorStateProps = {
  error?: unknown;
  title?: string;
  description?: string;
  onRetry?: () => void;
  retryLabel?: string;
  className?: string;
};

export function ErrorState({
  error,
  title,
  description,
  onRetry,
  retryLabel = "Try again",
  className = "",
}: ErrorStateProps) {
  const safeError = toUserFacingError(error);
  const heading = title ?? safeError.title;
  const body = description ?? safeError.description;

  return (
    <section
      role="alert"
      aria-labelledby="error-state-heading"
      className={`rounded-3xl border border-rose-300/20 bg-rose-950/30 p-8 sm:p-10 ${className}`.trim()}
    >
      <h2
        id="error-state-heading"
        className="text-xl font-semibold tracking-tight text-white"
      >
        {heading}
      </h2>
      <p className="mt-3 max-w-2xl text-sm leading-7 text-slate-200">{body}</p>
      {onRetry ? (
        <div className="mt-6">
          <button
            type="button"
            onClick={onRetry}
            className="rounded-full bg-emerald-300 px-5 py-3 text-sm font-semibold text-slate-950 transition hover:bg-emerald-200 focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-emerald-200"
          >
            {retryLabel}
          </button>
        </div>
      ) : null}
    </section>
  );
}
