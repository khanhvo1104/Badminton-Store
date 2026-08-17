import { PRODUCT_LOAD_FAILURE_MESSAGE } from "@/features/products/constants";

export {
  PRODUCT_AUTH_DENIED_MESSAGE,
  PRODUCT_LOAD_FAILURE_MESSAGE,
} from "@/features/products/constants";

const PROVIDER_LEAK_PATTERN =
  /\b(sql|postgrest|permission denied|row-level|rls|jwt|token|stack|exception|storage\.objects|violates|duplicate key|23505|PGRST)\b/i;

export function sanitizeProductProviderError(error: unknown): string {
  void error;
  return PRODUCT_LOAD_FAILURE_MESSAGE;
}

export function assertNoProviderLeak(message: string): boolean {
  return !PROVIDER_LEAK_PATTERN.test(message);
}
