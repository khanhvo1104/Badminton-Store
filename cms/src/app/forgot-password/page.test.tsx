import { render, screen } from "@testing-library/react";
import { describe, expect, it, vi } from "vitest";

import { PublicEnvironmentError } from "@/lib/errors/public-environment-error";

const getPublicEnvironment = vi.hoisted(() => vi.fn());
const getCmsSiteUrl = vi.hoisted(() => vi.fn());

vi.mock("@/lib/env/public-env", () => ({
  getPublicEnvironment,
}));

vi.mock("@/lib/env/cms-site-url", () => ({
  getCmsSiteUrl,
}));

vi.mock("@/features/auth/actions/request-password-reset", () => ({
  requestPasswordReset: vi.fn(),
}));

vi.mock("react", async () => {
  const actual = await vi.importActual<typeof import("react")>("react");

  return {
    ...actual,
    useActionState: () => [
      { errorMessage: null, acknowledgement: null },
      vi.fn(),
    ],
  };
});

vi.mock("react-dom", async () => {
  const actual = await vi.importActual<typeof import("react-dom")>("react-dom");

  return {
    ...actual,
    useFormStatus: () => ({ pending: false }),
  };
});

describe("ForgotPasswordPage", () => {
  it("renders the recovery form when configuration is valid", async () => {
    getPublicEnvironment.mockReturnValue({
      supabaseUrl: "https://demo-project.supabase.co",
      supabasePublishableKey: "public-demo-key",
    });
    getCmsSiteUrl.mockReturnValue(new URL("https://cms.example.com"));

    const { default: ForgotPasswordPage } = await import(
      "@/app/forgot-password/page"
    );

    render(<ForgotPasswordPage />);

    expect(
      screen.getByRole("heading", { name: "Forgot password" }),
    ).toBeInTheDocument();
    expect(screen.getByLabelText("Email")).toBeInTheDocument();
    expect(
      screen.getByRole("button", { name: "Send recovery email" }),
    ).toBeInTheDocument();
  });

  it("renders a safe configuration state and never falls back to localhost", async () => {
    getPublicEnvironment.mockImplementation(() => {
      throw new PublicEnvironmentError("missing-url");
    });

    const { default: ForgotPasswordPage } = await import(
      "@/app/forgot-password/page"
    );

    render(<ForgotPasswordPage />);

    expect(
      screen.getByRole("heading", { name: "Configuration unavailable" }),
    ).toBeInTheDocument();
    expect(screen.queryByText(/localhost/i)).not.toBeInTheDocument();
    expect(screen.queryByLabelText("Email")).not.toBeInTheDocument();
  });
});
