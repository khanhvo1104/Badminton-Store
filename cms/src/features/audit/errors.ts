import { AUDIT_LOAD_FAILURE_MESSAGE } from "@/features/audit/constants";

export function sanitizeAuditProviderError(error: unknown): string {
  if (error === null || error === undefined) {
    return AUDIT_LOAD_FAILURE_MESSAGE;
  }

  if (typeof error === "object" && error !== null && "message" in error) {
    const message = (error as { message?: unknown }).message;
    if (typeof message === "string" && message.trim()) {
      const normalized = message.trim().toLowerCase();
      if (
        normalized.includes("not authorized") ||
        normalized.includes("permission denied")
      ) {
        return AUDIT_LOAD_FAILURE_MESSAGE;
      }
    }
  }

  return AUDIT_LOAD_FAILURE_MESSAGE;
}
