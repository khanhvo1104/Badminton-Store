"use client";

import { useRouter } from "next/navigation";

import { ErrorState } from "@/components/ui/error-state";

export default function ProductVariantsError({
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
      title="Variants unavailable"
      onRetry={() => {
        reset();
        router.refresh();
      }}
    />
  );
}
