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

vi.mock("@/features/auth/actions/login", () => ({
  INITIAL_LOGIN_FORM_STATE: {
    errorMessage: null,
  },
  login: vi.fn(),
}));

describe("LoginForm", () => {
  it("renders labeled email/password controls with safe defaults", async () => {
    useActionState.mockReturnValue([{ errorMessage: null }, vi.fn()]);
    useFormStatus.mockReturnValue({ pending: false });

    const { LoginForm } = await import("@/features/auth/components/login-form");

    render(<LoginForm />);

    expect(screen.getByLabelText("Email")).toHaveAttribute(
      "autocomplete",
      "email",
    );
    expect(screen.getByLabelText("Password")).toHaveAttribute(
      "autocomplete",
      "current-password",
    );
    expect(screen.getByRole("button", { name: "Sign in" })).toBeEnabled();
    expect(screen.getByRole("status")).toHaveTextContent("");
  });

  it("shows a disabled pending state during submission", async () => {
    useActionState.mockReturnValue([{ errorMessage: null }, vi.fn()]);
    useFormStatus.mockReturnValue({ pending: true });

    const { LoginForm } = await import("@/features/auth/components/login-form");

    render(<LoginForm />);

    expect(
      screen.getByRole("button", { name: "Signing in..." }),
    ).toBeDisabled();
    expect(
      screen.getByRole("button", { name: "Signing in..." }),
    ).toHaveAttribute("aria-disabled", "true");
  });

  it("announces sanitized errors", async () => {
    useActionState.mockReturnValue([
      { errorMessage: "We couldn't sign you in with those credentials." },
      vi.fn(),
    ]);
    useFormStatus.mockReturnValue({ pending: false });

    const { LoginForm } = await import("@/features/auth/components/login-form");

    render(<LoginForm />);

    expect(screen.getByRole("alert")).toHaveTextContent(
      "We couldn't sign you in with those credentials.",
    );
    expect(
      screen.queryByText(/token|sql|stack|secret/i),
    ).not.toBeInTheDocument();
  });
});
