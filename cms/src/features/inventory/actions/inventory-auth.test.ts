import { beforeEach, describe, expect, it, vi } from "vitest";

import { INITIAL_INVENTORY_FORM_STATE } from "@/features/inventory/adjustment-form-state";
import { INVENTORY_MUTATION_AUTH_DENIED_MESSAGE } from "@/features/inventory/constants";

const createSupabaseServerClient = vi.hoisted(() => vi.fn());
const authorizeCmsRequest = vi.hoisted(() => vi.fn());

vi.mock("@/lib/supabase/server", () => ({ createSupabaseServerClient }));
vi.mock("@/lib/auth/authorization", async () => {
  const actual = await vi.importActual<
    typeof import("@/lib/auth/authorization")
  >("@/lib/auth/authorization");
  return { ...actual, authorizeCmsRequest };
});

const VARIANT_ID = "40000000-0000-4000-8000-000000000001";

function adjustmentFormData(): FormData {
  const formData = new FormData();
  formData.set("operation", "add_stock");
  formData.set("quantity", "1");
  formData.set("reason", "received");
  return formData;
}

describe("inventory server action auth", () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it.each([
    ["anonymous", { kind: "anonymous" }],
    ["customer", { kind: "unauthorized" }],
    ["inactive", { kind: "unauthorized" }],
    ["malformed", { kind: "unauthorized" }],
    ["recovery", { kind: "unauthorized" }],
  ] as const)(
    "denies %s adjust without calling rpc",
    async (_label, authorization) => {
      const from = vi.fn();
      const rpc = vi.fn();
      authorizeCmsRequest.mockResolvedValue(authorization);
      createSupabaseServerClient.mockResolvedValue({ from, rpc });

      const { adjustInventory } = await import(
        "@/features/inventory/actions/adjust-inventory"
      );
      await expect(
        adjustInventory(
          VARIANT_ID,
          INITIAL_INVENTORY_FORM_STATE,
          adjustmentFormData(),
        ),
      ).resolves.toMatchObject({
        status: "error",
        message: INVENTORY_MUTATION_AUTH_DENIED_MESSAGE,
      });
      expect(from).not.toHaveBeenCalled();
      expect(rpc).not.toHaveBeenCalled();
    },
  );
});
