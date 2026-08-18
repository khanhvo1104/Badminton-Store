import { beforeEach, describe, expect, it, vi } from "vitest";

import { INITIAL_INVENTORY_FORM_STATE } from "@/features/inventory/adjustment-form-state";
import {
  ADJUST_CMS_INVENTORY_RPC,
  INVENTORY_NOT_FOUND_MESSAGE,
  INVENTORY_QUANTITY_INVALID_MESSAGE,
  INVENTORY_SUCCESS_ADJUSTED,
  inventoryAdjustmentPath,
} from "@/features/inventory/constants";

const requireInventoryActionAuth = vi.hoisted(() => vi.fn());
const revalidatePath = vi.hoisted(() => vi.fn());
const redirect = vi.hoisted(() => vi.fn());

vi.mock("@/features/inventory/action-utils", async () => {
  const actual = await vi.importActual<
    typeof import("@/features/inventory/action-utils")
  >("@/features/inventory/action-utils");
  return { ...actual, requireInventoryActionAuth };
});

vi.mock("next/cache", () => ({ revalidatePath }));
vi.mock("next/navigation", () => ({ redirect }));

const VARIANT_ID = "40000000-0000-4000-8000-000000000001";
const FORGED_VARIANT_ID = "40000000-0000-4000-8000-000000000088";

function validFormData(overrides: Record<string, string> = {}): FormData {
  const data = new FormData();
  data.set("operation", overrides.operation ?? "add_stock");
  data.set("quantity", overrides.quantity ?? "2");
  data.set("allow_backorder", overrides.allow_backorder ?? "");
  data.set("reason", overrides.reason ?? "received");
  data.set("note", overrides.note ?? "");
  data.set("variant_id", overrides.variant_id ?? FORGED_VARIANT_ID);
  return data;
}

describe("adjustInventory", () => {
  beforeEach(() => {
    requireInventoryActionAuth.mockReset();
    revalidatePath.mockReset();
    redirect.mockReset();
  });

  it("binds the route variant id and ignores FormData variant_id", async () => {
    const rpc = vi
      .fn()
      .mockResolvedValue({ data: [{ variant_id: VARIANT_ID }], error: null });
    requireInventoryActionAuth.mockResolvedValue({
      ok: true,
      supabase: { rpc },
    });

    redirect.mockImplementation(() => {
      throw new Error("NEXT_REDIRECT");
    });

    const { adjustInventory } = await import(
      "@/features/inventory/actions/adjust-inventory"
    );
    await expect(
      adjustInventory(
        VARIANT_ID,
        INITIAL_INVENTORY_FORM_STATE,
        validFormData(),
      ),
    ).rejects.toThrow("NEXT_REDIRECT");

    expect(rpc).toHaveBeenCalledWith(ADJUST_CMS_INVENTORY_RPC, {
      p_variant_id: VARIANT_ID,
      p_operation: "add_stock",
      p_quantity: 2,
      p_allow_backorder: null,
      p_reason: "received",
      p_note: null,
    });
    expect(revalidatePath).toHaveBeenCalledWith("/dashboard/inventory");
    expect(revalidatePath).toHaveBeenCalledWith(
      inventoryAdjustmentPath(VARIANT_ID),
    );
    expect(redirect).toHaveBeenCalledWith(
      `${inventoryAdjustmentPath(VARIANT_ID)}?success=${INVENTORY_SUCCESS_ADJUSTED}`,
    );
  });

  it("rejects a forged non-uuid route id before rpc", async () => {
    const rpc = vi.fn();
    requireInventoryActionAuth.mockResolvedValue({
      ok: true,
      supabase: { rpc },
    });

    const { adjustInventory } = await import(
      "@/features/inventory/actions/adjust-inventory"
    );
    const result = await adjustInventory(
      "not-a-uuid",
      INITIAL_INVENTORY_FORM_STATE,
      validFormData(),
    );
    expect(result.message).toBe(INVENTORY_NOT_FOUND_MESSAGE);
    expect(rpc).not.toHaveBeenCalled();
    expect(redirect).not.toHaveBeenCalled();
  });

  it("fail-closes non-integer quantities without calling rpc", async () => {
    const rpc = vi.fn();
    requireInventoryActionAuth.mockResolvedValue({
      ok: true,
      supabase: { rpc },
    });

    const { adjustInventory } = await import(
      "@/features/inventory/actions/adjust-inventory"
    );
    const result = await adjustInventory(
      VARIANT_ID,
      INITIAL_INVENTORY_FORM_STATE,
      validFormData({ quantity: "1.5" }),
    );
    expect(result.fieldErrors.quantity).toBe(
      INVENTORY_QUANTITY_INVALID_MESSAGE,
    );
    expect(rpc).not.toHaveBeenCalled();
  });
});
