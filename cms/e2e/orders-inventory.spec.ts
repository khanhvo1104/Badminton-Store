import { expect, test } from "@playwright/test";

import { E2E_ORDER } from "./fixtures/accounts";
import { loginAsStaff } from "./helpers/auth";
import { expectNoSensitiveLeak } from "./helpers/security";

test.describe("CMS inventory and order read boundaries", () => {
  test("staff can read inventory explorer without privileged cost fields", async ({
    page,
  }) => {
    await loginAsStaff(page);
    await page.goto("/dashboard/inventory");
    await expect(
      page.getByRole("heading", { name: /Inventory/i }),
    ).toBeVisible();
    await expect(page.getByText(/cost price|cost_price/i)).toHaveCount(0);
    await expectNoSensitiveLeak(page);
  });

  test("staff can open a seeded order and see transition confirmation boundary", async ({
    page,
  }) => {
    await loginAsStaff(page);
    await page.goto("/dashboard/orders");
    await expect(
      page.getByRole("link", { name: E2E_ORDER.orderNumber }).first(),
    ).toBeVisible();
    await page
      .getByRole("link", { name: E2E_ORDER.orderNumber })
      .first()
      .click();
    await expect(page).toHaveURL(
      new RegExp(`/dashboard/orders/${E2E_ORDER.id}`),
    );
    await expect(page.getByText(E2E_ORDER.recipientName).first()).toBeVisible();

    await page.getByRole("button", { name: "Update status" }).click();
    const dialog = page.getByRole("dialog");
    await expect(dialog).toBeVisible();
    await expect(
      page.getByRole("heading", { name: "Confirm order status change" }),
    ).toBeVisible();
    await page.getByRole("button", { name: "Keep editing" }).click();
    await expect(dialog).toBeHidden();
    await expectNoSensitiveLeak(page);
  });
});
