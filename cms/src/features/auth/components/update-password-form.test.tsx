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

vi.mock("@/features/auth/actions/update-password", () => ({
  updatePassword: vi.fn(),
}));

describe("UpdatePasswordForm", () => {
  it("renders labeled password controls with safe defaults", async () => {
    useActionState.mockReturnValue([{ errorMessage: null }, vi.fn()]);
    useFormStatus.mockReturnValue({ pending: false });

    const { UpdatePasswordForm } = await import(
      "@/features/auth/components/update-password-form"
    );

    render(<UpdatePasswordForm />);

    expect(screen.getByLabelText("New password")).toHaveAttribute(
      "autocomplete",
      "new-password",
    );
    expect(screen.getByLabelText("Confirm password")).toHaveAttribute(
      "autocomplete",
      "new-password",
    );
    expect(
      screen.getByRole("button", { name: "Update password" }),
    ).toBeEnabled();
  });

  it("shows a disabled pending state during submission", async () => {
    useActionState.mockReturnValue([{ errorMessage: null }, vi.fn()]);
    useFormStatus.mockReturnValue({ pending: true });

    const { UpdatePasswordForm } = await import(
      "@/features/auth/components/update-password-form"
    );

    render(<UpdatePasswordForm />);

    expect(
      screen.getByRole("button", { name: "Updating password..." }),
    ).toBeDisabled();
  });

  it("announces sanitized update failures", async () => {
    useActionState.mockReturnValue([
      { errorMessage: "We couldn't update your password. Try again." },
      vi.fn(),
    ]);
    useFormStatus.mockReturnValue({ pending: false });

    const { UpdatePasswordForm } = await import(
      "@/features/auth/components/update-password-form"
    );

    render(<UpdatePasswordForm />);

    expect(screen.getByRole("alert")).toHaveTextContent(
      "We couldn't update your password. Try again.",
    );
    expect(
      screen.queryByText(/token|sql|stack|secret/i),
    ).not.toBeInTheDocument();
  });
});
