import { render, screen } from "@testing-library/react";
import { describe, expect, it, vi } from "vitest";

const redirect = vi.hoisted(() => vi.fn());
const createSupabaseServerClient = vi.hoisted(() => vi.fn());
const authorizeCmsRequest = vi.hoisted(() => vi.fn());

vi.mock("next/navigation", () => ({
  redirect,
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

describe("DashboardPage", () => {
  it("redirects anonymous access to login", async () => {
    createSupabaseServerClient.mockResolvedValue({});
    authorizeCmsRequest.mockResolvedValue({ kind: "anonymous" });
    redirect.mockImplementation(() => {
      throw new Error("NEXT_REDIRECT:/login");
    });

    const { default: DashboardPage } = await import("@/app/dashboard/page");

    await expect(DashboardPage()).rejects.toThrow("NEXT_REDIRECT:/login");
  });

  it("redirects unauthorized authenticated access to the sanitized page", async () => {
    createSupabaseServerClient.mockResolvedValue({});
    authorizeCmsRequest.mockResolvedValue({ kind: "unauthorized" });
    redirect.mockImplementation(() => {
      throw new Error("NEXT_REDIRECT:/unauthorized");
    });

    const { default: DashboardPage } = await import("@/app/dashboard/page");

    await expect(DashboardPage()).rejects.toThrow(
      "NEXT_REDIRECT:/unauthorized",
    );
  });

  it("renders a minimal greeting for authorized staff and admins", async () => {
    createSupabaseServerClient.mockResolvedValue({});
    authorizeCmsRequest.mockResolvedValue({
      kind: "authorized",
      profile: {
        id: "staff-1",
        fullName: "Alex Coach",
        role: "staff",
        isActive: true,
      },
    });

    const { default: DashboardPage } = await import("@/app/dashboard/page");
    const element = await DashboardPage();

    render(element);

    expect(
      screen.getByRole("heading", { name: "Welcome back, Alex Coach." }),
    ).toBeInTheDocument();
    expect(screen.getByText(/active staff profile/i)).toBeInTheDocument();
    expect(screen.queryByText(/email|token|sql/i)).not.toBeInTheDocument();
  });
});
