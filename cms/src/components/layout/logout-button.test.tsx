import { render, screen } from "@testing-library/react";
import { describe, expect, it, vi } from "vitest";

const useFormStatus = vi.hoisted(() => vi.fn());

vi.mock("react-dom", async () => {
  const actual = await vi.importActual<typeof import("react-dom")>("react-dom");

  return {
    ...actual,
    useFormStatus,
  };
});

vi.mock("@/features/auth/actions/logout", () => ({
  logout: vi.fn(),
}));

describe("LogoutButton", () => {
  it("shows a disabled pending state while signing out", async () => {
    useFormStatus.mockReturnValue({ pending: true });

    const { LogoutButton } = await import("@/components/layout/logout-button");

    render(<LogoutButton />);

    const button = screen.getByRole("button", { name: "Signing out..." });
    expect(button).toBeDisabled();
    expect(button).toHaveAttribute("aria-disabled", "true");
  });

  it("renders the ready sign-out control", async () => {
    useFormStatus.mockReturnValue({ pending: false });

    const { LogoutButton } = await import("@/components/layout/logout-button");

    render(<LogoutButton />);

    expect(screen.getByRole("button", { name: "Sign out" })).toBeEnabled();
  });
});
