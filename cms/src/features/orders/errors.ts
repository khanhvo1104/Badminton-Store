import {
  ORDERS_GENERIC_FAILURE_MESSAGE,
  ORDERS_LOAD_FAILURE_MESSAGE,
} from "@/features/orders/constants";

const PROVIDER_LEAK_PATTERN =
  /\b(sql|postgrest|permission denied|row-level|rls|jwt|token|stack|exception|storage\.objects|violates|duplicate key|23505|PGRST)\b/i;

export function toOrderMutationFailureMessage(error: unknown): string {
  void error;
  return ORDERS_GENERIC_FAILURE_MESSAGE;
}

export function sanitizeOrdersProviderError(error: unknown): string {
  void error;
  return ORDERS_LOAD_FAILURE_MESSAGE;
}

export function isNotFoundError(error: unknown): boolean {
  if (!isRecord(error)) {
    return false;
  }
  const code = typeof error.code === "string" ? error.code : "";
  const message =
    typeof error.message === "string" ? error.message.toLowerCase() : "";
  return (
    code === "P0002" ||
    code === "PGRST116" ||
    code === "02000" ||
    message === "not found"
  );
}

export function assertNoProviderLeak(message: string): boolean {
  return !PROVIDER_LEAK_PATTERN.test(message);
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null;
}
