import {
  STAFF_GENERIC_FAILURE_MESSAGE,
  STAFF_LAST_ADMIN_DENIED_MESSAGE,
  STAFF_LOAD_FAILURE_MESSAGE,
  STAFF_NOT_FOUND_MESSAGE,
  STAFF_SELF_CHANGE_DENIED_MESSAGE,
} from "@/features/staff/constants";

const PROVIDER_LEAK_PATTERN =
  /\b(sql|postgrest|permission denied|row-level|rls|jwt|token|stack|exception|violates|duplicate key|23505|PGRST|auth\.users)\b/i;

export function toStaffMutationFailureMessage(error: unknown): string {
  if (!isRecord(error)) {
    return STAFF_GENERIC_FAILURE_MESSAGE;
  }

  const message =
    typeof error.message === "string" ? error.message.toLowerCase() : "";
  const code = typeof error.code === "string" ? error.code : "";

  if (code === "42501" || message === "not authorized") {
    if (message.includes("last admin")) {
      return STAFF_LAST_ADMIN_DENIED_MESSAGE;
    }
    return STAFF_SELF_CHANGE_DENIED_MESSAGE;
  }

  if (
    code === "P0002" ||
    code === "PGRST116" ||
    code === "02000" ||
    message === "not found"
  ) {
    return STAFF_NOT_FOUND_MESSAGE;
  }

  return STAFF_GENERIC_FAILURE_MESSAGE;
}

export function sanitizeStaffProviderError(error: unknown): string {
  void error;
  return STAFF_LOAD_FAILURE_MESSAGE;
}

export function mapInviteFunctionError(status: number, body: unknown): string {
  if (!isRecord(body) || typeof body.error !== "string") {
    return STAFF_GENERIC_FAILURE_MESSAGE;
  }

  const message = body.error;
  if (PROVIDER_LEAK_PATTERN.test(message)) {
    return STAFF_GENERIC_FAILURE_MESSAGE;
  }

  if (status === 429) {
    return message;
  }

  return message;
}

export function assertNoProviderLeak(message: string): boolean {
  return !PROVIDER_LEAK_PATTERN.test(message);
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null;
}
