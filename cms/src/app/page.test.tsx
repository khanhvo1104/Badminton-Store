import { describe, expect, it, vi } from "vitest";
const redirect = vi.hoisted(() => vi.fn());
const createSupabaseServerClient = vi.hoisted(() => vi.fn());

vi.mock("next/navigation", () => ({
  redirect,
}));

vi.mock("@/lib/supabase/server", () => ({
  createSupabaseServerClient,
}));

describe("Home route", () => {
  it("routes anonymous requests to login", async () => {
    createSupabaseServerClient.mockResolvedValue({
      auth: {
        getClaims: vi.fn().mockResolvedValue({
          data: { claims: null },
          error: null,
        }),
      },
    });
    redirect.mockImplementation(() => {
      throw new Error("NEXT_REDIRECT:/login");
    });

    const { default: Home } = await import("@/app/page");

    await expect(Home()).rejects.toThrow("NEXT_REDIRECT:/login");
    expect(redirect).toHaveBeenCalledWith("/login");
  });

  it("routes verified identities to the dashboard", async () => {
    createSupabaseServerClient.mockResolvedValue({
      auth: {
        getClaims: vi.fn().mockResolvedValue({
          data: { claims: { sub: "staff-1" } },
          error: null,
        }),
      },
    });
    redirect.mockImplementation(() => {
      throw new Error("NEXT_REDIRECT:/dashboard");
    });

    const { default: Home } = await import("@/app/page");

    await expect(Home()).rejects.toThrow("NEXT_REDIRECT:/dashboard");
    expect(redirect).toHaveBeenCalledWith("/dashboard");
  });
});
