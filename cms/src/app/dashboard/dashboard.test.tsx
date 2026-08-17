import { fireEvent, render, screen } from "@testing-library/react";
import { describe, expect, it, vi } from "vitest";

const redirect = vi.hoisted(() => vi.fn());
const createSupabaseServerClient = vi.hoisted(() => vi.fn());
const authorizeCmsRequest = vi.hoisted(() => vi.fn());

vi.mock("next/navigation", () => ({
  redirect,
  usePathname: () => "/dashboard",
}));

vi.mock("@/lib/supabase/server", () => ({
  createSupabaseServerClient,
}));

vi.mock("@/lib/auth/authorization", async () => {
  const actual = await vi.importActual<
    typeof import("@/lib/auth/authorization")
  >("@/lib/auth/authorization");

  return {
    ...actual,
    authorizeCmsRequest,
  };
});

vi.mock("@/features/auth/actions/logout", () => ({
  logout: vi.fn(),
}));

describe("DashboardLayout", () => {
  it("redirects anonymous access to login", async () => {
    createSupabaseServerClient.mockResolvedValue({});
    authorizeCmsRequest.mockResolvedValue({ kind: "anonymous" });
    redirect.mockImplementation(() => {
      throw new Error("NEXT_REDIRECT:/login");
    });

    const { default: DashboardLayout } = await import("@/app/dashboard/layout");

    await expect(
      DashboardLayout({ children: <div>child</div> }),
    ).rejects.toThrow("NEXT_REDIRECT:/login");
  });

  it("redirects unauthorized authenticated access to the sanitized page", async () => {
    createSupabaseServerClient.mockResolvedValue({});
    authorizeCmsRequest.mockResolvedValue({ kind: "unauthorized" });
    redirect.mockImplementation(() => {
      throw new Error("NEXT_REDIRECT:/unauthorized");
    });

    const { default: DashboardLayout } = await import("@/app/dashboard/layout");

    await expect(
      DashboardLayout({ children: <div>child</div> }),
    ).rejects.toThrow("NEXT_REDIRECT:/unauthorized");
  });

  it("renders the protected shell for authorized staff", async () => {
    createSupabaseServerClient.mockResolvedValue({});
    authorizeCmsRequest.mockResolvedValue({
      kind: "authorized",
      profile: {
        id: "staff-1",
        fullName: "Alex Coach",
        role: "staff",
        isActive: true,
      },
    });

    const { default: DashboardLayout } = await import("@/app/dashboard/layout");
    const element = await DashboardLayout({
      children: <h1>Catalog management workspace</h1>,
    });

    render(element);

    expect(
      screen.getByRole("heading", { name: "Catalog management workspace" }),
    ).toBeInTheDocument();
    expect(
      screen.getByRole("link", { name: /skip to content/i }),
    ).toHaveAttribute("href", "#main-content");
    expect(screen.getAllByText("Alex Coach").length).toBeGreaterThan(0);
    expect(screen.queryByText(/email|token|sql/i)).not.toBeInTheDocument();
  });
});

describe("DashboardOverviewPage", () => {
  it("links only to protected placeholder routes without live metrics", async () => {
    const { default: DashboardOverviewPage } = await import(
      "@/app/dashboard/page"
    );

    render(<DashboardOverviewPage />);

    expect(
      screen.getByRole("heading", { name: "Catalog management workspace" }),
    ).toBeInTheDocument();
    expect(screen.getByRole("link", { name: /categories/i })).toHaveAttribute(
      "href",
      "/dashboard/categories",
    );
    expect(screen.getByRole("link", { name: /brands/i })).toHaveAttribute(
      "href",
      "/dashboard/brands",
    );
    expect(screen.getByRole("link", { name: /products/i })).toHaveAttribute(
      "href",
      "/dashboard/products",
    );
    expect(screen.getByRole("link", { name: /inventory/i })).toHaveAttribute(
      "href",
      "/dashboard/inventory",
    );
    expect(
      screen.queryByText(/live total|orders today|revenue/i),
    ).not.toBeInTheDocument();
  });
});

describe("dashboard placeholder pages", () => {
  it("renders product and inventory placeholders", async () => {
    const { default: ProductsPage } = await import(
      "@/app/dashboard/products/page"
    );
    const { default: InventoryPage } = await import(
      "@/app/dashboard/inventory/page"
    );

    const cases = [
      {
        page: <ProductsPage />,
        heading: "Products",
        emptyTitle: "Product management comes next",
      },
      {
        page: <InventoryPage />,
        heading: "Inventory",
        emptyTitle: "Inventory tools come next",
      },
    ];

    for (const item of cases) {
      const view = render(item.page);
      expect(
        screen.getByRole("heading", { name: item.heading }),
      ).toBeInTheDocument();
      expect(
        screen.getByRole("heading", { name: item.emptyTitle }),
      ).toBeInTheDocument();
      view.unmount();
    }

    render(<InventoryPage />);
    expect(
      screen.queryByText(/select \*|mutation|sql/i),
    ).not.toBeInTheDocument();
  });
});

describe("dashboard loading and error routes", () => {
  it("renders the shared loading pattern", async () => {
    const { default: DashboardLoading } = await import(
      "@/app/dashboard/loading"
    );

    render(<DashboardLoading />);

    expect(
      screen.getByRole("status", { name: "Loading dashboard content" }),
    ).toBeInTheDocument();
  });

  it("retries through the error boundary reset callback", async () => {
    const reset = vi.fn();
    const consoleError = vi
      .spyOn(console, "error")
      .mockImplementation(() => undefined);

    const { default: DashboardError } = await import("@/app/dashboard/error");

    render(
      <DashboardError
        error={new Error("internal sql token=secret")}
        reset={reset}
      />,
    );

    expect(
      screen.getByRole("heading", { name: "Something went wrong" }),
    ).toBeInTheDocument();
    expect(screen.queryByText(/sql|token=secret/i)).not.toBeInTheDocument();

    fireEvent.click(screen.getByRole("button", { name: "Retry" }));
    expect(reset).toHaveBeenCalledTimes(1);

    consoleError.mockRestore();
  });
});
