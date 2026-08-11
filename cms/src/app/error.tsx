"use client";

import Link from "next/link";
import { useEffect } from "react";

import { PublicEnvironmentError } from "@/lib/errors/public-environment-error";
import { toUserFacingError } from "@/lib/errors/to-user-facing-error";

type GlobalErrorProps = {
  error: Error & { digest?: string };
  reset: () => void;
};

export default function GlobalError({ error, reset }: GlobalErrorProps) {
  const safeError = toUserFacingError(error);

  useEffect(() => {
    if (error instanceof PublicEnvironmentError) {
      console.error("Public configuration error.");
      return;
    }

    console.error(error);
  }, [error]);

  return (
    <div className="min-h-screen bg-slate-950 px-6 py-12 text-slate-50">
      <main className="mx-auto flex min-h-[calc(100vh-6rem)] max-w-3xl flex-col justify-center rounded-3xl border border-white/10 bg-white/5 p-8 shadow-2xl shadow-slate-950/30 sm:p-12">
        <p className="text-sm font-semibold uppercase tracking-[0.3em] text-emerald-300">
          Badminton Store administration
        </p>
        <h1 className="mt-4 text-3xl font-semibold tracking-tight text-white sm:text-4xl">
          {safeError.title}
        </h1>
        <p className="mt-4 max-w-2xl text-base leading-7 text-slate-200">
          {safeError.description}
        </p>
        <div className="mt-8 flex flex-wrap gap-4">
          <button
            type="button"
            onClick={reset}
            className="rounded-full bg-emerald-300 px-5 py-3 text-sm font-semibold text-slate-950 transition hover:bg-emerald-200 focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-emerald-200"
          >
            Retry startup
          </button>
          <Link
            href="/"
            className="rounded-full border border-white/15 px-5 py-3 text-sm font-semibold text-white transition hover:border-white/30 hover:bg-white/5 focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-white"
          >
            Return to home
          </Link>
        </div>
      </main>
    </div>
  );
}
