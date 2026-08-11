import { describe, expect, it, vi } from "vitest";

const redirect = vi.hoisted(() => vi.fn());
const createSupabaseServerClient = vi.hoisted(() => vi.fn());

vi.mock("next/navigation", () => ({
  redirect,
}));

vi.mock("@/lib/supabase/server", () => ({
  createSupabaseServerClient,
}));

describe("logout action", () => {
  it("redirects anonymous users to login without signing out", async () => {
    const signOut = vi.fn();
    createSupabaseServerClient.mockResolvedValue({
      auth: {
        getClaims: vi.fn().mockResolvedValue({
          data: null,
          error: new Error("expired"),
        }),
        signOut,
      },
    });

    redirect.mockImplementation(() => {
      throw new Error("NEXT_REDIRECT:/login");
    });

    const { logout } = await import("@/features/auth/actions/logout");

    await expect(logout()).rejects.toThrow("NEXT_REDIRECT:/login");
    expect(signOut).not.toHaveBeenCalled();
  });

  it("validates identity before signing out and redirects to login", async () => {
    const signOut = vi.fn().mockResolvedValue({ error: null });
    createSupabaseServerClient.mockResolvedValue({
      auth: {
        getClaims: vi.fn().mockResolvedValue({
          data: { claims: { sub: "staff-1" } },
          error: null,
        }),
        signOut,
      },
    });

    redirect.mockImplementation(() => {
      throw new Error("NEXT_REDIRECT:/login");
    });

    const { logout } = await import("@/features/auth/actions/logout");

    await expect(logout()).rejects.toThrow("NEXT_REDIRECT:/login");
    expect(signOut).toHaveBeenCalledTimes(1);
    expect(redirect).toHaveBeenCalledWith("/login");
  });
});
