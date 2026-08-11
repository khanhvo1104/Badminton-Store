import { render, screen } from "@testing-library/react";
import { describe, expect, it, vi } from "vitest";

import { PublicEnvironmentError } from "@/lib/errors/public-environment-error";

const getPublicEnvironment = vi.fn();

vi.mock("@/lib/env/public-env", () => ({
  getPublicEnvironment,
}));

describe("Home route", () => {
  it("renders the landing shell when public configuration is valid", async () => {
    getPublicEnvironment.mockReturnValue({
      supabaseUrl: "https://demo-project.supabase.co/",
      supabasePublishableKey: "public-demo-key",
    });

    const { default: Home } = await import("@/app/page");

    render(<Home />);

    expect(
      screen.getByRole("heading", { level: 1, name: "Badminton Store CMS" }),
    ).toBeInTheDocument();
  });

  it("renders sanitized configuration guidance on route startup failure", async () => {
    getPublicEnvironment.mockImplementation(() => {
      throw new PublicEnvironmentError("missing-url");
    });

    const { default: Home } = await import("@/app/page");

    render(<Home />);

    expect(
      screen.getByRole("heading", { name: "Configuration unavailable" }),
    ).toBeInTheDocument();
    expect(
      screen.getByText(/public configuration is set correctly/i),
    ).toBeInTheDocument();
    expect(
      screen.queryByText(/NEXT_PUBLIC_SUPABASE_URL|secret|token/i),
    ).not.toBeInTheDocument();
  });
});
