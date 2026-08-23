import { render, screen } from "@testing-library/react";
import { beforeEach, describe, expect, it, vi } from "vitest";

vi.mock("@/lib/supabase/server", () => ({
  createSupabaseServerClient: vi.fn(),
}));

vi.mock("@/features/staff/queries", () => ({
  listStaffMembers: vi.fn(),
}));

vi.mock("@/lib/auth/authorization", async (importOriginal) => {
  const actual =
    await importOriginal<typeof import("@/lib/auth/authorization")>();
  return {
    ...actual,
    authorizeCmsAdminRequest: vi.fn(),
  };
});

import StaffPage from "@/app/dashboard/staff/page";
import { authorizeCmsAdminRequest } from "@/lib/auth/authorization";
import { listStaffMembers } from "@/features/staff/queries";

describe("StaffPage", () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it("shows admin denial for staff profiles", async () => {
    vi.mocked(authorizeCmsAdminRequest).mockResolvedValue({
      kind: "unauthorized",
    });

    render(await StaffPage({ searchParams: Promise.resolve({}) }));

    expect(
      screen.getByText(
        /staff management is available only to active admin accounts/i,
      ),
    ).toBeInTheDocument();
    expect(listStaffMembers).not.toHaveBeenCalled();
  });

  it("renders the staff directory for admins", async () => {
    vi.mocked(authorizeCmsAdminRequest).mockResolvedValue({
      kind: "authorized",
      profile: {
        id: "admin-1",
        fullName: "Admin",
        role: "admin",
        isActive: true,
      },
    });
    vi.mocked(listStaffMembers).mockResolvedValue({
      ok: true,
      result: {
        items: [
          {
            profileId: "staff-1",
            fullName: "Alex Coach",
            email: "alex@example.invalid",
            role: "staff",
            isActive: true,
            createdAt: "2026-01-01T00:00:00.000Z",
          },
        ],
        totalCount: 1,
        pagination: { page: 1, pageSize: 20, offset: 0 },
        totalPages: 1,
        query: {
          search: "",
          role: "all",
          active: "all",
          sort: "name_asc",
          pagination: { page: 1, pageSize: 20, offset: 0 },
        },
        hasActiveFilters: false,
      },
    });

    render(await StaffPage({ searchParams: Promise.resolve({}) }));

    expect(
      screen.getByRole("heading", { name: /staff management/i }),
    ).toBeInTheDocument();
    expect(screen.getByText("alex@example.invalid")).toBeInTheDocument();
  });
});
