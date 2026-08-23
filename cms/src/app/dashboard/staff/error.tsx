"use client";

import { ErrorState } from "@/components/ui/error-state";
import { STAFF_LOAD_FAILURE_MESSAGE } from "@/features/staff/constants";

export default function StaffError() {
  return (
    <div className="mx-auto max-w-6xl">
      <ErrorState
        title="Staff management unavailable"
        description={STAFF_LOAD_FAILURE_MESSAGE}
      />
    </div>
  );
}
