import { beforeEach, describe, expect, it, vi } from "vitest";

import { MEDIA_AUTH_DENIED_MESSAGE } from "@/features/media/constants";

const authorizeCmsRequest = vi.hoisted(() => vi.fn());

vi.mock("@/lib/auth/authorization", async () => {
  const actual = await vi.importActual<
    typeof import("@/lib/auth/authorization")
  >("@/lib/auth/authorization");
  return { ...actual, authorizeCmsRequest };
});

const PRODUCT_ID = "30000000-0000-4000-8000-000000000001";

describe("product media queries", () => {
  beforeEach(() => {
    authorizeCmsRequest.mockReset();
  });
  it("authorizes before reading images or variants", async () => {
    authorizeCmsRequest.mockResolvedValue({ kind: "unauthorized" });
    const from = vi.fn();
    const { getProductMediaPage } = await import("@/features/media/queries");
    const result = await getProductMediaPage({
      supabase: { auth: { getClaims: vi.fn() }, from } as never,
      productId: PRODUCT_ID,
      supabaseUrl: "https://example.supabase.co",
    });
    expect(result).toEqual({
      ok: false,
      message: MEDIA_AUTH_DENIED_MESSAGE,
    });
    expect(from).not.toHaveBeenCalled();
  });

  it("treats a non-uuid product id as not found without querying", async () => {
    const from = vi.fn();
    const { getProductMediaPage } = await import("@/features/media/queries");
    const result = await getProductMediaPage({
      supabase: { auth: { getClaims: vi.fn() }, from } as never,
      productId: "not-a-uuid",
      supabaseUrl: "https://example.supabase.co",
    });
    expect(result).toMatchObject({ ok: false, notFound: true });
    expect(authorizeCmsRequest).not.toHaveBeenCalled();
    expect(from).not.toHaveBeenCalled();
  });
});
