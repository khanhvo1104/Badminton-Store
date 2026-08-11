import { fireEvent, render, screen, within } from "@testing-library/react";
import { describe, expect, it, vi } from "vitest";

const usePathname = vi.hoisted(() => vi.fn());

vi.mock("next/navigation", () => ({
  usePathname,
}));

vi.mock("@/features/auth/actions/logout", () => ({
  logout: vi.fn(),
}));

describe("DashboardShell", () => {
  it("renders skip link, main landmark, account context, and current nav", async () => {
    usePathname.mockReturnValue("/dashboard/categories");

    const { DashboardShell } = await import(
      "@/components/layout/dashboard-shell"
    );

    render(
      <DashboardShell profile={{ fullName: "Alex Coach", role: "staff" }}>
        <h1>Categories</h1>
      </DashboardShell>,
    );

    const skip = screen.getByRole("link", { name: /skip to content/i });
    expect(skip).toHaveAttribute("href", "#main-content");

    const main = screen.getByRole("main");
    expect(main).toHaveAttribute("id", "main-content");
    expect(
      within(main).getByRole("heading", { name: "Categories" }),
    ).toBeInTheDocument();

    expect(screen.getAllByText("Alex Coach").length).toBeGreaterThan(0);
    expect(screen.getAllByText("Staff").length).toBeGreaterThan(0);

    const currentLinks = screen.getAllByRole("link", { name: "Categories" });
    expect(
      currentLinks.some((link) => link.getAttribute("aria-current") === "page"),
    ).toBe(true);
  });

  it("falls back to a safe display name for admins without a full name", async () => {
    usePathname.mockReturnValue("/dashboard");

    const { DashboardShell } = await import(
      "@/components/layout/dashboard-shell"
    );

    render(
      <DashboardShell profile={{ fullName: null, role: "admin" }}>
        <h1>Overview</h1>
      </DashboardShell>,
    );

    expect(screen.getAllByText("Admin").length).toBeGreaterThan(0);
  });
});

describe("DashboardNavigation", () => {
  it("toggles mobile navigation, closes on Escape, and restores focus", async () => {
    usePathname.mockReturnValue("/dashboard");

    const { DashboardNavigation } = await import(
      "@/components/layout/dashboard-navigation"
    );

    render(<DashboardNavigation />);

    const openButton = screen.getByRole("button", { name: "Open navigation" });
    openButton.focus();
    fireEvent.click(openButton);

    expect(
      screen.getByRole("button", { name: "Close navigation" }),
    ).toHaveAttribute("aria-expanded", "true");

    const panel = document.getElementById(
      openButton.getAttribute("aria-controls") ?? "",
    );
    expect(panel).not.toHaveAttribute("hidden");

    fireEvent.keyDown(document, { key: "Escape" });

    expect(
      screen.getByRole("button", { name: "Open navigation" }),
    ).toHaveAttribute("aria-expanded", "false");
    expect(panel).toHaveAttribute("hidden");
    expect(document.activeElement).toBe(
      screen.getByRole("button", { name: "Open navigation" }),
    );
  });

  it("closes mobile navigation when a route is selected", async () => {
    usePathname.mockReturnValue("/dashboard");

    const { DashboardNavigation } = await import(
      "@/components/layout/dashboard-navigation"
    );

    render(<DashboardNavigation />);

    fireEvent.click(screen.getByRole("button", { name: "Open navigation" }));
    const brandsLinks = screen.getAllByRole("link", { name: "Brands" });
    const mobileBrands = brandsLinks[brandsLinks.length - 1];
    fireEvent.click(mobileBrands!);

    expect(
      screen.getByRole("button", { name: "Open navigation" }),
    ).toHaveAttribute("aria-expanded", "false");
  });
});
