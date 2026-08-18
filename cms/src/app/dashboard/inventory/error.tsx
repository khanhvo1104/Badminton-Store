"use client";

import { useRouter } from "next/navigation";

import { ErrorState } from "@/components/ui/error-state";

export default function InventoryError({
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
      title="Inventory unavailable"
      onRetry={() => {
        reset();
        router.refresh();
      }}
    />
  );
}
