import {
  DASHBOARD_GENERIC_FAILURE_MESSAGE,
  DASHBOARD_LOAD_FAILURE_MESSAGE,
} from "@/features/operational-dashboard/constants";

const PROVIDER_LEAK_PATTERN =
  /\b(sql|postgrest|permission denied|row-level|rls|jwt|token|stack|exception|violates|duplicate key|23505|PGRST)\b/i;

export function sanitizeDashboardProviderError(error: unknown): string {
  void error;
  return DASHBOARD_LOAD_FAILURE_MESSAGE;
}

export function toDashboardFailureMessage(error: unknown): string {
  void error;
  return DASHBOARD_GENERIC_FAILURE_MESSAGE;
}

export function assertNoDashboardProviderLeak(message: string): boolean {
  return !PROVIDER_LEAK_PATTERN.test(message);
}
