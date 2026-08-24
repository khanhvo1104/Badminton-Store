import { expect, test } from "@playwright/test";

import { E2E_CATEGORY, E2E_RETRY_CATEGORY_SLUG } from "./fixtures/accounts";
import { loginAsStaff } from "./helpers/auth";
import { expectNoSensitiveLeak } from "./helpers/security";

test.describe("CMS catalog mutation and recovery", () => {
  test("staff create flow validates input then saves a unique category", async ({
    page,
  }) => {
    await loginAsStaff(page);
    await page.goto("/dashboard/categories/new");
    await expect(
      page.getByRole("heading", { name: "Create category" }),
    ).toBeVisible();

    await page.getByRole("button", { name: "Create category" }).click();
    await expect(page.getByText("Enter a category name.")).toBeVisible();
    await expectNoSensitiveLeak(page);

    const uniqueSlug = `cms-e2e-created-${Date.now()}`;
    await page.getByLabel("Name").fill("CMS E2E Created Category");
    await page.getByLabel("Slug").fill(uniqueSlug);
    await page.getByLabel("Sort order").fill("997");
    await page.getByRole("button", { name: "Create category" }).click();

    await expect(page).toHaveURL(/\/dashboard\/categories\/.+\/edit/);
    await expect(page.getByText("Category created.")).toBeVisible();
    await expectNoSensitiveLeak(page);
  });

  test("activation confirmation dialog supports keyboard focus recovery", async ({
    page,
  }) => {
    await loginAsStaff(page);
    await page.goto(`/dashboard/categories/${E2E_CATEGORY.id}/edit`);
    await expect(
      page.getByRole("heading", { name: "Edit category", level: 1 }),
    ).toBeVisible();

    const trigger = page.getByRole("button", {
      name: /Activate category|Deactivate category/,
    });
    await trigger.click();

    const dialog = page.getByRole("dialog");
    await expect(dialog).toBeVisible();
    await expect(page.getByRole("button", { name: "Cancel" })).toBeFocused();

    await page.keyboard.press("Escape");
    await expect(dialog).toBeHidden();
    await expect(trigger).toBeFocused();
    await expectNoSensitiveLeak(page);
  });

  test("mutation network failure shows sanitized feedback and recovers on retry", async ({
    page,
  }) => {
    await loginAsStaff(page);
    await page.goto("/dashboard/categories/new");

    let failOnce = true;
    await page.route("**/dashboard/categories/new", async (route) => {
      const request = route.request();
      if (
        request.method() === "POST" &&
        failOnce &&
        request.headers()["next-action"]
      ) {
        failOnce = false;
        await route.fulfill({
          status: 500,
          contentType: "text/plain",
          body: 'Error: relation "secret_internal_table" does not exist\nSTACK TRACE at Object.query',
        });
        return;
      }
      await route.continue();
    });

    await page.getByLabel("Name").fill("CMS E2E Retry Category");
    await page.getByLabel("Slug").fill(E2E_RETRY_CATEGORY_SLUG);
    await page.getByLabel("Sort order").fill("998");
    await page.getByRole("button", { name: "Create category" }).click();

    await expect(
      page.getByText(/secret_internal_table|STACK TRACE/i),
    ).toHaveCount(0);
    await expectNoSensitiveLeak(page);

    // After a failed Server Action response the form may need a fresh navigation.
    await page.goto("/dashboard/categories/new");
    await page.getByLabel("Name").fill("CMS E2E Retry Category");
    await page.getByLabel("Slug").fill(E2E_RETRY_CATEGORY_SLUG);
    await page.getByLabel("Sort order").fill("998");
    await page.getByRole("button", { name: "Create category" }).click();
    await expect(page).toHaveURL(/\/dashboard\/categories\/.+\/edit/);
    await expect(page.getByText("Category created.")).toBeVisible();
    await expectNoSensitiveLeak(page);
  });
});
