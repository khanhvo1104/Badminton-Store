import type { ReactNode } from "react";
import { render, screen } from "@testing-library/react";
import { beforeEach, describe, expect, it, vi } from "vitest";

const createSupabaseServerClient = vi.hoisted(() => vi.fn());
const authorizeCmsRequest = vi.hoisted(() => vi.fn());
const listInventory = vi.hoisted(() => vi.fn());

vi.mock("@/lib/supabase/server", () => ({ createSupabaseServerClient }));
vi.mock("@/lib/auth/authorization", async () => {
  const actual = await vi.importActual<
    typeof import("@/lib/auth/authorization")
  >("@/lib/auth/authorization");
  return { ...actual, authorizeCmsRequest };
});
vi.mock("@/features/inventory/queries", async () => {
  const actual = await vi.importActual<
    typeof import("@/features/inventory/queries")
  >("@/features/inventory/queries");
  return { ...actual, listInventory };
});
vi.mock("next/link", () => ({
  default: ({ href, children }: { href: string; children: ReactNode }) => (
    <a href={href}>{children}</a>
  ),
}));

describe("Inventory page", () => {
  beforeEach(() => {
    createSupabaseServerClient.mockReset();
    authorizeCmsRequest.mockReset();
    listInventory.mockReset();
    createSupabaseServerClient.mockResolvedValue({ tagged: "ssr-client" });
  });

  it("loads a bounded inventory page through the SSR client", async () => {
    authorizeCmsRequest.mockResolvedValue({
      kind: "authorized",
      profile: {
        id: "staff-1",
        fullName: "Alex Coach",
        role: "staff",
        isActive: true,
      },
    });
    listInventory.mockResolvedValue({
      ok: true,
      result: {
        items: [],
        totalCount: 0,
        pagination: { page: 1, pageSize: 20, from: 0, to: 19 },
        totalPages: 0,
        hasActiveFilters: false,
        query: {
          search: "",
          stock: "all",
          sort: "updated_desc",
          pagination: { page: 1, pageSize: 20, from: 0, to: 19 },
        },
      },
    });

    const { default: InventoryPage } = await import(
      "@/app/dashboard/inventory/page"
    );
    const element = await InventoryPage({
      searchParams: Promise.resolve({ page: "1" }),
    });
    render(element);

    expect(listInventory).toHaveBeenCalledWith(
      expect.objectContaining({
        supabase: { tagged: "ssr-client" },
        query: expect.objectContaining({
          pagination: { page: 1, pageSize: 20, from: 0, to: 19 },
          sort: "updated_desc",
        }),
      }),
    );
    expect(screen.getByRole("heading", { name: "Inventory" })).toBeTruthy();
    expect(screen.queryByText(/cost_price|barcode/i)).toBeNull();
  });

  it("shows a sanitized error when authorization is denied", async () => {
    authorizeCmsRequest.mockResolvedValue({ kind: "unauthorized" });

    const { default: InventoryPage } = await import(
      "@/app/dashboard/inventory/page"
    );
    const element = await InventoryPage({
      searchParams: Promise.resolve({}),
    });
    render(element);

    expect(listInventory).not.toHaveBeenCalled();
    expect(
      screen.getByText("You do not have permission to view inventory."),
    ).toBeTruthy();
  });
});
