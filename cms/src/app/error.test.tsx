import { render, screen } from "@testing-library/react";
import { describe, expect, it, vi } from "vitest";

import GlobalError from "@/app/error";
import { PublicEnvironmentError } from "@/lib/errors/public-environment-error";

describe("GlobalError", () => {
  it("renders sanitized startup copy for public configuration failures", () => {
    const reset = vi.fn();
    const consoleError = vi
      .spyOn(console, "error")
      .mockImplementation(() => undefined);
    const error = new PublicEnvironmentError("invalid-url");
    error.message =
      "NEXT_PUBLIC_SUPABASE_URL=https://secret-project.supabase.co token=super-secret";

    render(<GlobalError error={error} reset={reset} />);

    expect(
      screen.getByRole("heading", { name: "Configuration unavailable" }),
    ).toBeInTheDocument();
    expect(
      screen.getByText(/public configuration is set correctly/i),
    ).toBeInTheDocument();
    expect(
      screen.queryByText(/secret-project\.supabase\.co|super-secret|token=/i),
    ).not.toBeInTheDocument();
    expect(screen.queryByText(/stack/i)).not.toBeInTheDocument();
    expect(consoleError).toHaveBeenCalledWith("Public configuration error.");

    consoleError.mockRestore();
  });
});
