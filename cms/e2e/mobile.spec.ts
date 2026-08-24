import { expect, test } from "@playwright/test";

import { loginAsStaff } from "./helpers/auth";
import { expectNoSensitiveLeak } from "./helpers/security";

test.describe("CMS mobile viewport smoke", () => {
  test("staff can sign in and open dashboard on mobile", async ({ page }) => {
    await loginAsStaff(page);
    await expect(page.locator("#main-content")).toBeVisible();
    await page.goto("/dashboard/inventory");
    await expect(
      page.getByRole("heading", { name: /Inventory/i }),
    ).toBeVisible();
    await expectNoSensitiveLeak(page);
  });
});
