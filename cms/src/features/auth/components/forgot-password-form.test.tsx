import { render, screen } from "@testing-library/react";
import { describe, expect, it, vi } from "vitest";

const useActionState = vi.hoisted(() => vi.fn());
const useFormStatus = vi.hoisted(() => vi.fn());

vi.mock("react", async () => {
  const actual = await vi.importActual<typeof import("react")>("react");

  return {
    ...actual,
    useActionState,
  };
});

vi.mock("react-dom", async () => {
  const actual = await vi.importActual<typeof import("react-dom")>("react-dom");

  return {
    ...actual,
    useFormStatus,
  };
});

vi.mock("@/features/auth/actions/request-password-reset", () => ({
  requestPasswordReset: vi.fn(),
}));

describe("ForgotPasswordForm", () => {
  it("renders a labeled email control and login link", async () => {
    useActionState.mockReturnValue([
      { errorMessage: null, acknowledgement: null },
      vi.fn(),
    ]);
    useFormStatus.mockReturnValue({ pending: false });

    const { ForgotPasswordForm } = await import(
      "@/features/auth/components/forgot-password-form"
    );

    render(<ForgotPasswordForm />);

    expect(screen.getByLabelText("Email")).toHaveAttribute(
      "autocomplete",
      "email",
    );
    expect(
      screen.getByRole("button", { name: "Send recovery email" }),
    ).toBeEnabled();
    expect(
      screen.getByRole("link", { name: "Back to sign in" }),
    ).toHaveAttribute("href", "/login");
  });

  it("announces the same acknowledgement for recovery requests", async () => {
    useActionState.mockReturnValue([
      {
        errorMessage: null,
        acknowledgement:
          "If an account exists for that email, we sent password recovery instructions.",
      },
      vi.fn(),
    ]);
    useFormStatus.mockReturnValue({ pending: false });

    const { ForgotPasswordForm } = await import(
      "@/features/auth/components/forgot-password-form"
    );

    render(<ForgotPasswordForm />);

    expect(screen.getByRole("status")).toHaveTextContent(
      "If an account exists for that email, we sent password recovery instructions.",
    );
    expect(
      screen.queryByText(/not found|does not exist|unknown user/i),
    ).not.toBeInTheDocument();
  });

  it("announces validation errors without account existence details", async () => {
    useActionState.mockReturnValue([
      { errorMessage: "Enter a valid email address.", acknowledgement: null },
      vi.fn(),
    ]);
    useFormStatus.mockReturnValue({ pending: false });

    const { ForgotPasswordForm } = await import(
      "@/features/auth/components/forgot-password-form"
    );

    render(<ForgotPasswordForm />);

    expect(screen.getByRole("alert")).toHaveTextContent(
      "Enter a valid email address.",
    );
    expect(
      screen.queryByText(/token|sql|exists|not found/i),
    ).not.toBeInTheDocument();
  });
});
