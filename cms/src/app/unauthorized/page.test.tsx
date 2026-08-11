import { render, screen } from "@testing-library/react";
import { describe, expect, it, vi } from "vitest";

vi.mock("@/lib/env/public-env", () => ({
  getPublicEnvironment: () => ({
    supabaseUrl: "https://demo-project.supabase.co",
    supabasePublishableKey: "public-demo-key",
  }),
}));

describe("UnauthorizedPage", () => {
  it("renders a sanitized unauthorized experience", async () => {
    const { default: UnauthorizedPage } = await import(
      "@/app/unauthorized/page"
    );

    render(<UnauthorizedPage />);

    expect(
      screen.getByRole("heading", { name: "You can't access this CMS area." }),
    ).toBeInTheDocument();
    expect(
      screen.getByText(/available only to approved active staff accounts/i),
    ).toBeInTheDocument();
    expect(
      screen.queryByText(/customer|inactive|missing profile|sql/i),
    ).not.toBeInTheDocument();
  });
});
