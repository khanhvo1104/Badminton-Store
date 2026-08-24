import { expect, test } from "@playwright/test";

import { E2E_CATEGORY } from "./fixtures/accounts";
import { loginAsAdmin, loginAsStaff } from "./helpers/auth";
import { expectNoSeriousAxeViolations } from "./helpers/axe";
import { expectNoSensitiveLeak } from "./helpers/security";

test.describe("CMS accessibility", () => {
  test("login page has no serious or critical axe violations", async ({
    page,
  }) => {
    await page.goto("/login");
    await expect(
      page.getByRole("heading", { name: "CMS sign in" }),
    ).toBeVisible();
    await expectNoSeriousAxeViolations(page);
    await expectNoSensitiveLeak(page);
  });

  test("dashboard overview has no serious or critical axe violations", async ({
    page,
  }) => {
    await loginAsStaff(page);
    await page.goto("/dashboard");
    await expect(
      page.getByRole("heading", { name: "Operational overview" }),
    ).toBeVisible();
    await expectNoSeriousAxeViolations(page);
  });

  test("authenticated list, form, and modal pages pass axe checks", async ({
    page,
  }) => {
    await loginAsStaff(page);

    await page.goto("/dashboard/categories");
    await expect(
      page.getByRole("heading", { name: "Category management" }),
    ).toBeVisible();
    await expectNoSeriousAxeViolations(page);

    await page.goto("/dashboard/categories/new");
    await expect(
      page.getByRole("heading", { name: "Create category" }),
    ).toBeVisible();
    await expectNoSeriousAxeViolations(page);

    await page.goto(`/dashboard/categories/${E2E_CATEGORY.id}/edit`);
    const trigger = page.getByRole("button", {
      name: /Activate category|Deactivate category/,
    });
    await trigger.click();
    await expect(page.getByRole("dialog")).toBeVisible();
    await expectNoSeriousAxeViolations(page);
    await page.getByRole("button", { name: "Cancel" }).click();

    await loginAsAdmin(page);
    await page.goto("/dashboard/staff");
    await expect(
      page.getByRole("heading", { name: "Staff management" }),
    ).toBeVisible();
    await expectNoSeriousAxeViolations(page);
  });
});
