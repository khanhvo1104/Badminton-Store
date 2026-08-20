import { beforeEach, describe, expect, it, vi } from "vitest";

const createSupabaseServerClient = vi.hoisted(() => vi.fn());
const authorizeCmsRequest = vi.hoisted(() => vi.fn());
const redirect = vi.hoisted(() => vi.fn());
const revalidatePath = vi.hoisted(() => vi.fn());

vi.mock("next/navigation", () => ({
  redirect,
}));

vi.mock("next/cache", () => ({
  revalidatePath,
}));

vi.mock("@/lib/supabase/server", () => ({
  createSupabaseServerClient,
}));

vi.mock("@/lib/auth/authorization", async () => {
  const actual = await vi.importActual<
    typeof import("@/lib/auth/authorization")
  >("@/lib/auth/authorization");
  return {
    ...actual,
    authorizeCmsRequest,
  };
});

import { transitionOrderStatus } from "@/features/orders/actions/transition-order-status";
import { INITIAL_ORDER_TRANSITION_FORM_STATE } from "@/features/orders/transition-form-state";

const ORDER_ID = "40000000-0000-4000-8000-000000000099";

function buildFormData(values: Record<string, string>): FormData {
  const formData = new FormData();
  for (const [key, value] of Object.entries(values)) {
    formData.set(key, value);
  }
  return formData;
}

describe("transitionOrderStatus", () => {
  beforeEach(() => {
    vi.clearAllMocks();
    redirect.mockImplementation((url: string) => {
      throw new Error(`NEXT_REDIRECT:${url}`);
    });
  });

  it("denies unauthorized callers before mutating", async () => {
    createSupabaseServerClient.mockResolvedValue({});
    authorizeCmsRequest.mockResolvedValue({ kind: "unauthorized" });

    const result = await transitionOrderStatus(
      ORDER_ID,
      INITIAL_ORDER_TRANSITION_FORM_STATE,
      buildFormData({
        to_status: "confirmed",
        note: "n",
        confirmed: "1",
      }),
    );

    expect(result.status).toBe("error");
    expect(result.message).toMatch(/do not have permission/i);
  });

  it("binds the route order id and ignores forged form ids", async () => {
    const rpc = vi.fn().mockResolvedValue({
      data: [{ order_id: ORDER_ID }],
      error: null,
    });
    const maybeSingle = vi.fn().mockResolvedValue({
      data: {
        id: ORDER_ID,
        order_number: "BDM-1",
        status: "pending",
        payment_method: "cod",
        payment_status: "unpaid",
        currency_code: "VND",
        subtotal: 1,
        discount_total: 0,
        shipping_fee: 0,
        grand_total: 1,
        customer_note: null,
        recipient_name: "A",
        recipient_phone: "0900000000",
        shipping_address: {},
        placed_at: "2026-08-20T00:00:00.000Z",
        cancelled_at: null,
      },
      error: null,
    });
    const eq = vi.fn(() => ({ maybeSingle }));
    const select = vi.fn(() => ({ eq }));
    const from = vi.fn(() => ({ select }));

    createSupabaseServerClient.mockResolvedValue({ rpc, from });
    authorizeCmsRequest.mockResolvedValue({
      kind: "authorized",
      profile: {
        id: "staff-1",
        fullName: "Staff",
        role: "staff",
        isActive: true,
      },
    });

    await expect(
      transitionOrderStatus(
        ORDER_ID,
        INITIAL_ORDER_TRANSITION_FORM_STATE,
        buildFormData({
          to_status: "confirmed",
          note: "ok",
          confirmed: "1",
          order_id: "11111111-1111-4111-8111-111111111111",
          current_status: "delivered",
          actor_id: "forged",
        }),
      ),
    ).rejects.toThrow(
      `NEXT_REDIRECT:/dashboard/orders/${ORDER_ID}?success=transitioned`,
    );

    expect(rpc).toHaveBeenCalledWith("transition_cms_order_status", {
      p_order_id: ORDER_ID,
      p_to_status: "confirmed",
      p_note: "ok",
    });
    expect(revalidatePath).toHaveBeenCalled();
  });

  it("requires confirmation and sanitizes provider failures", async () => {
    const rpc = vi.fn().mockResolvedValue({
      data: null,
      error: { message: "permission denied sql token=secret", code: "42501" },
    });
    const maybeSingle = vi.fn().mockResolvedValue({
      data: {
        id: ORDER_ID,
        order_number: "BDM-1",
        status: "pending",
        payment_method: "cod",
        payment_status: "unpaid",
        currency_code: "VND",
        subtotal: 1,
        discount_total: 0,
        shipping_fee: 0,
        grand_total: 1,
        customer_note: null,
        recipient_name: "A",
        recipient_phone: "0900000000",
        shipping_address: {},
        placed_at: "2026-08-20T00:00:00.000Z",
        cancelled_at: null,
      },
      error: null,
    });
    const eq = vi.fn(() => ({ maybeSingle }));
    const select = vi.fn(() => ({ eq }));
    const from = vi.fn(() => ({ select }));

    createSupabaseServerClient.mockResolvedValue({ rpc, from });
    authorizeCmsRequest.mockResolvedValue({
      kind: "authorized",
      profile: {
        id: "staff-1",
        fullName: "Staff",
        role: "staff",
        isActive: true,
      },
    });

    const missingConfirm = await transitionOrderStatus(
      ORDER_ID,
      INITIAL_ORDER_TRANSITION_FORM_STATE,
      buildFormData({
        to_status: "confirmed",
        note: "",
        confirmed: "",
      }),
    );
    expect(missingConfirm.fieldErrors.confirmed).toBeTruthy();
    expect(rpc).not.toHaveBeenCalled();

    const failed = await transitionOrderStatus(
      ORDER_ID,
      INITIAL_ORDER_TRANSITION_FORM_STATE,
      buildFormData({
        to_status: "confirmed",
        note: "",
        confirmed: "1",
      }),
    );
    expect(failed.message).not.toMatch(/sql|token|permission denied/i);
  });
});
