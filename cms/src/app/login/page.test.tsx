import { render, screen } from "@testing-library/react";
import { describe, expect, it, vi } from "vitest";

vi.mock("react", async () => {
  const actual = await vi.importActual<typeof import("react")>("react");

  return {
    ...actual,
    useActionState: () => [{ errorMessage: null }, vi.fn()],
  };
});

vi.mock("react-dom", async () => {
  const actual = await vi.importActual<typeof import("react-dom")>("react-dom");

  return {
    ...actual,
    useFormStatus: () => ({ pending: false }),
  };
});

vi.mock("@/lib/env/public-env", () => ({
  getPublicEnvironment: () => ({
    supabaseUrl: "https://demo-project.supabase.co",
    supabasePublishableKey: "public-demo-key",
  }),
}));

vi.mock("@/features/auth/actions/login", () => ({
  login: vi.fn(),
}));

describe("LoginPage", () => {
  it("renders the recovery link without changing the sign-in form", async () => {
    const { default: LoginPage } = await import("@/app/login/page");

    render(
      await LoginPage({
        searchParams: Promise.resolve({}),
      }),
    );

    expect(
      screen.getByRole("heading", { name: "CMS sign in" }),
    ).toBeInTheDocument();
    expect(screen.getByLabelText("Email")).toBeInTheDocument();
    expect(screen.getByLabelText("Password")).toBeInTheDocument();
    expect(screen.getByRole("button", { name: "Sign in" })).toBeInTheDocument();
    expect(
      screen.getByRole("link", { name: "Forgot password?" }),
    ).toHaveAttribute("href", "/forgot-password");
  });

  it("shows a generic password-updated message from an allow-listed status", async () => {
    const { default: LoginPage } = await import("@/app/login/page");

    render(
      await LoginPage({
        searchParams: Promise.resolve({ status: "password-updated" }),
      }),
    );

    expect(
      screen.getByText(
        "Your password was updated. Sign in with your new password.",
      ),
    ).toBeInTheDocument();
    expect(
      screen.queryByText(/token|password=|sql|secret/i),
    ).not.toBeInTheDocument();
  });

  it("ignores unknown status values so provider errors cannot be reflected", async () => {
    const { default: LoginPage } = await import("@/app/login/page");

    render(
      await LoginPage({
        searchParams: Promise.resolve({
          status: "User not found: leaked token",
        }),
      }),
    );

    expect(
      screen.queryByText(/User not found: leaked token/i),
    ).not.toBeInTheDocument();
  });
});
