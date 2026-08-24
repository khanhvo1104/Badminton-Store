import { expect, test } from "@playwright/test";

import { E2E_ACCOUNTS } from "./fixtures/accounts";
import { loginAs, loginAsAdmin, loginAsStaff } from "./helpers/auth";
import { expectNoSensitiveLeak } from "./helpers/security";

test.describe("CMS auth and authorization boundaries", () => {
  test("unauthenticated protected routes redirect to login", async ({
    page,
  }) => {
    await page.goto("/dashboard");
    await expect(page).toHaveURL(/\/login$/);
    await expect(
      page.getByRole("heading", { name: "CMS sign in" }),
    ).toBeVisible();
    await expectNoSensitiveLeak(page);

    await page.goto("/dashboard/staff");
    await expect(page).toHaveURL(/\/login$/);
  });

  test("customer accounts fail closed to unauthorized", async ({ page }) => {
    await loginAs(page, "customer");
    await expect(page).toHaveURL(/\/unauthorized$/);
    await expect(
      page.getByRole("heading", { name: /can.?t access this CMS area/i }),
    ).toBeVisible();
    await expect(page.getByText("Invite staff member")).toHaveCount(0);
    await expectNoSensitiveLeak(page);
  });

  test("staff can open dashboard routes but not admin-only surfaces", async ({
    page,
  }) => {
    await loginAsStaff(page);
    await expect(
      page.getByRole("heading", { name: "Operational overview" }),
    ).toBeVisible();
    await expect(page.getByRole("link", { name: "Staff" })).toHaveCount(0);
    await expect(page.getByRole("link", { name: "Audit" })).toHaveCount(0);

    await page.goto("/dashboard/staff");
    await expect(
      page.getByText(
        "Staff management is available only to active admin accounts.",
      ),
    ).toBeVisible();
    await expect(
      page.getByRole("heading", { name: "Invite staff member" }),
    ).toHaveCount(0);
    await expectNoSensitiveLeak(page);

    await page.goto("/dashboard/audit");
    await expect(
      page.getByText(
        "The audit trail is available only to active admin accounts.",
      ),
    ).toBeVisible();
    await expectNoSensitiveLeak(page);
  });

  test("admin can open admin-only staff surface", async ({ page }) => {
    await loginAsAdmin(page);
    await page.goto("/dashboard/staff");
    await expect(
      page.getByRole("heading", { name: "Staff management" }),
    ).toBeVisible();
    await expect(page.getByText(E2E_ACCOUNTS.staff.fullName)).toBeVisible();
    await expectNoSensitiveLeak(page);
  });

  test("invalid credentials stay on login with sanitized failure", async ({
    page,
  }) => {
    await page.goto("/login");
    await page.getByLabel("Email").fill(E2E_ACCOUNTS.staff.email);
    await page.getByLabel("Password").fill("definitely-wrong-password");
    await page.getByRole("button", { name: "Sign in" }).click();
    await expect(
      page.getByText("We couldn't sign you in with those credentials."),
    ).toBeVisible();
    await expect(page).toHaveURL(/\/login/);
    await expectNoSensitiveLeak(page);
  });
});
