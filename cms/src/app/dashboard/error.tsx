"use client";

import { useEffect } from "react";

import { ErrorState } from "@/components/ui/error-state";
import { isPublicEnvironmentError } from "@/lib/errors/public-environment-error";

type DashboardErrorProps = {
  error: Error & { digest?: string };
  reset: () => void;
};

export default function DashboardError({ error, reset }: DashboardErrorProps) {
  useEffect(() => {
    if (isPublicEnvironmentError(error)) {
      console.error("Public configuration error.");
      return;
    }

    console.error("Dashboard segment error.");
  }, [error]);

  return (
    <div className="mx-auto max-w-4xl">
      <ErrorState error={error} onRetry={reset} retryLabel="Retry" />
    </div>
  );
}
