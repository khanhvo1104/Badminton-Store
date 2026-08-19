"use client";

import { useRouter } from "next/navigation";

import { ErrorState } from "@/components/ui/error-state";

export default function ProductMediaError({
  error,
  reset,
}: {
  error: Error & { digest?: string };
  reset: () => void;
}) {
  const router = useRouter();

  return (
    <ErrorState
      error={error}
      title="Product images unavailable"
      onRetry={() => {
        reset();
        router.refresh();
      }}
    />
  );
}
