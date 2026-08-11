import { render, screen, within } from "@testing-library/react";
import { describe, expect, it } from "vitest";

import { CmsLandingShell } from "@/features/landing/components/cms-landing-shell";

describe("CmsLandingShell", () => {
  it("renders the accessible CMS foundation shell", () => {
    render(<CmsLandingShell />);

    expect(
      screen.getByRole("heading", { level: 1, name: "Badminton Store CMS" }),
    ).toBeInTheDocument();

    const main = screen.getByRole("main");
    expect(
      within(main).getByText(/independently runnable Next\.js application/i),
    ).toBeInTheDocument();
    expect(
      within(main).getByText(/Auth arrives in TASK-025/i),
    ).toBeInTheDocument();

    expect(screen.getByRole("banner")).toBeInTheDocument();
    expect(screen.getByRole("contentinfo")).toBeInTheDocument();
    expect(
      screen.getByRole("link", { name: /skip to content/i }),
    ).toBeInTheDocument();
  });
});
