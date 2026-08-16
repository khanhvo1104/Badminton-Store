"use client";

import { useRouter } from "next/navigation";

import { ErrorState } from "@/components/ui/error-state";

export default function CategoriesError({
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
      title="Categories unavailable"
      onRetry={() => {
        reset();
        router.refresh();
      }}
    />
  );
}
