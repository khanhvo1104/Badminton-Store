import { expect, type Page } from "@playwright/test";

const SENSITIVE_LEAK_PATTERN =
  /\b(sqlstate|postgrest|permission denied|row-level security|\brls\b|service[_ -]?role|stack trace|violates unique|duplicate key|23505|PGRST\d+|relation "[^"]+"|SELECT \*|BEGIN;|supabase_admin)\b/i;

export async function expectNoSensitiveLeak(page: Page) {
  const text = await page.locator("body").innerText();
  expect(SENSITIVE_LEAK_PATTERN.test(text)).toBe(false);
}

export function assertSanitizedMessage(message: string) {
  expect(SENSITIVE_LEAK_PATTERN.test(message)).toBe(false);
  expect(message.length).toBeGreaterThan(0);
}
