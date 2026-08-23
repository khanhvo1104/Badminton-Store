"use client";

import { ErrorState } from "@/components/ui/error-state";
import { AUDIT_LOAD_FAILURE_MESSAGE } from "@/features/audit/constants";

export default function AuditError() {
  return (
    <div className="mx-auto max-w-6xl">
      <ErrorState
        title="Audit trail unavailable"
        description={AUDIT_LOAD_FAILURE_MESSAGE}
      />
    </div>
  );
}
