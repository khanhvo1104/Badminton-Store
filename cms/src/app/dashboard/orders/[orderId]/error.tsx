"use client";

import { useRouter } from "next/navigation";

import { ErrorState } from "@/components/ui/error-state";

export default function OrderDetailError({
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
      title="Unable to load order"
      onRetry={() => {
        reset();
        router.refresh();
      }}
    />
  );
}
