import { expect, test } from "@playwright/test";

import { loginAsStaff } from "./helpers/auth";
import { expectNoSensitiveLeak } from "./helpers/security";

test.describe("CMS session expiry fail-closed", () => {
  test("cleared session cookies reject dashboard access", async ({ page }) => {
    await loginAsStaff(page);
    await expect(page).toHaveURL(/\/dashboard/);

    await page.context().clearCookies();
    await page.goto("/dashboard/categories");
    await expect(page).toHaveURL(/\/login/);
    await expect(
      page.getByRole("heading", { name: "CMS sign in" }),
    ).toBeVisible();
    await expect(page.getByText("Create category")).toHaveCount(0);
    await expectNoSensitiveLeak(page);
  });

  test("corrupted auth cookie fails closed to login", async ({ page }) => {
    await loginAsStaff(page);
    const cookies = await page.context().cookies();
    const authCookies = cookies.filter((cookie) =>
      /auth-token|sb-/i.test(cookie.name),
    );
    expect(authCookies.length).toBeGreaterThan(0);

    for (const cookie of authCookies) {
      await page.context().addCookies([
        {
          ...cookie,
          value: "invalid.session.payload",
        },
      ]);
    }

    await page.goto("/dashboard");
    await expect(page).toHaveURL(/\/(login|unauthorized)/);
    await expect(page.getByText("Invite staff member")).toHaveCount(0);
    await expectNoSensitiveLeak(page);
  });
});
