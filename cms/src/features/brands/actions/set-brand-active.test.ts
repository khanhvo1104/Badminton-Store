import { beforeEach, describe, expect, it, vi } from "vitest";

import { INITIAL_BRAND_ACTIVATION_STATE } from "@/features/brands/brand-form-state";
import { BRAND_ACTIVATION_CONFIRM_REQUIRED_MESSAGE } from "@/features/brands/constants";

const requireBrandActionAuth = vi.hoisted(() => vi.fn());
const revalidatePath = vi.hoisted(() => vi.fn());
const redirect = vi.hoisted(() => vi.fn());

vi.mock("@/features/brands/action-utils", async () => {
  const actual = await vi.importActual<
    typeof import("@/features/brands/action-utils")
  >("@/features/brands/action-utils");
  return { ...actual, requireBrandActionAuth };
});

vi.mock("next/cache", () => ({ revalidatePath }));
vi.mock("next/navigation", () => ({ redirect }));

const BRAND_ID = "20000000-0000-4000-8000-000000000001";

describe("setBrandActive", () => {
  beforeEach(() => {
    requireBrandActionAuth.mockReset();
    revalidatePath.mockReset();
    redirect.mockReset();
    redirect.mockImplementation((path: string) => {
      throw new Error(`NEXT_REDIRECT:${path}`);
    });
  });

  it("requires confirmation before activation", async () => {
    requireBrandActionAuth.mockResolvedValue({
      ok: true,
      supabase: { from: vi.fn() },
    });

    const { setBrandActive } = await import(
      "@/features/brands/actions/set-brand-active"
    );
    const formData = new FormData();
    formData.set("id", BRAND_ID);
    formData.set("is_active", "true");

    const result = await setBrandActive(
      INITIAL_BRAND_ACTIVATION_STATE,
      formData,
    );
    expect(result.message).toBe(BRAND_ACTIVATION_CONFIRM_REQUIRED_MESSAGE);
    expect(result.fieldErrors.confirmed).toBe(
      BRAND_ACTIVATION_CONFIRM_REQUIRED_MESSAGE,
    );
    expect(requireBrandActionAuth).not.toHaveBeenCalled();
  });

  it("activates after confirmation", async () => {
    const maybeSingle = vi.fn().mockResolvedValue({
      data: {
        id: BRAND_ID,
        is_active: false,
      },
      error: null,
    });
    const eq = vi.fn().mockResolvedValue({ error: null });
    const update = vi.fn(() => ({ eq }));
    requireBrandActionAuth.mockResolvedValue({
      ok: true,
      supabase: {
        from: () => ({
          select: () => ({ eq: () => ({ maybeSingle }) }),
          update,
        }),
      },
    });

    const { setBrandActive } = await import(
      "@/features/brands/actions/set-brand-active"
    );
    const formData = new FormData();
    formData.set("id", BRAND_ID);
    formData.set("is_active", "true");
    formData.set("confirmed", "yes");

    await expect(
      setBrandActive(INITIAL_BRAND_ACTIVATION_STATE, formData),
    ).rejects.toThrow(/success=activated/);
    expect(update).toHaveBeenCalled();
    expect(revalidatePath).toHaveBeenCalledWith("/dashboard/brands");
  });
});
