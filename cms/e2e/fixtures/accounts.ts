/**
 * Deterministic disposable CMS E2E fixtures for local Supabase only.
 * Do not log these values in tests, reporters, or browser artifacts.
 */

export const E2E_PASSWORD = "CmsE2e-LocalOnly-Passw0rd!";

export const E2E_ACCOUNTS = {
  admin: {
    id: "a4300000-0000-4000-8000-000000000001",
    email: "cms-e2e-admin@example.invalid",
    fullName: "CMS E2E Admin",
    role: "admin" as const,
  },
  staff: {
    id: "a4300000-0000-4000-8000-000000000002",
    email: "cms-e2e-staff@example.invalid",
    fullName: "CMS E2E Staff",
    role: "staff" as const,
  },
  customer: {
    id: "a4300000-0000-4000-8000-000000000003",
    email: "cms-e2e-customer@example.invalid",
    fullName: "CMS E2E Customer",
    role: "customer" as const,
  },
} as const;

export const E2E_ORDER = {
  id: "a4300000-0000-4000-8000-000000000010",
  orderNumber: "BDM-E2E-0001",
  recipientName: "E2E Recipient",
  recipientPhone: "0901000001",
} as const;

export const E2E_CATEGORY = {
  id: "a4300000-0000-4000-8000-000000000020",
  name: "CMS E2E Category",
  slug: "cms-e2e-category",
} as const;

export const E2E_RETRY_CATEGORY_SLUG = "cms-e2e-retry-category";

export type E2EAccountKey = keyof typeof E2E_ACCOUNTS;
