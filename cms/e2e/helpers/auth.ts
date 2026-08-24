import type { Page } from "@playwright/test";

import {
  E2E_ACCOUNTS,
  E2E_PASSWORD,
  type E2EAccountKey,
} from "../fixtures/accounts";

export async function loginAs(page: Page, accountKey: E2EAccountKey) {
  const account = E2E_ACCOUNTS[accountKey];
  await page.goto("/login");
  await page.getByLabel("Email").fill(account.email);
  await page.getByLabel("Password").fill(E2E_PASSWORD);
  await page.getByRole("button", { name: "Sign in" }).click();

  if (accountKey === "customer") {
    // Login action redirects to /dashboard first; layout then fail-closes.
    await page.waitForURL(/\/unauthorized$/, { timeout: 30_000 });
    return;
  }

  await page.waitForURL(/\/dashboard(?:\/|$)/, { timeout: 30_000 });
}

export async function loginAsStaff(page: Page) {
  await loginAs(page, "staff");
}

export async function loginAsAdmin(page: Page) {
  await loginAs(page, "admin");
}
