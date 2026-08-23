import { render, screen } from "@testing-library/react";
import { beforeEach, describe, expect, it, vi } from "vitest";

vi.mock("@/lib/supabase/server", () => ({
  createSupabaseServerClient: vi.fn(),
}));

vi.mock("@/features/audit/queries", () => ({
  listAuditEvents: vi.fn(),
}));

vi.mock("@/lib/auth/authorization", async (importOriginal) => {
  const actual =
    await importOriginal<typeof import("@/lib/auth/authorization")>();
  return {
    ...actual,
    authorizeCmsAdminRequest: vi.fn(),
  };
});

import AuditPage from "@/app/dashboard/audit/page";
import { listAuditEvents } from "@/features/audit/queries";
import { authorizeCmsAdminRequest } from "@/lib/auth/authorization";

import { parseAuditExplorerQuery } from "@/features/audit/validation";

describe("AuditPage", () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it("shows admin denial for staff profiles", async () => {
    vi.mocked(authorizeCmsAdminRequest).mockResolvedValue({
      kind: "unauthorized",
    });

    render(await AuditPage({ searchParams: Promise.resolve({}) }));

    expect(
      screen.getByText(
        /audit trail is available only to active admin accounts/i,
      ),
    ).toBeInTheDocument();
    expect(listAuditEvents).not.toHaveBeenCalled();
  });

  it("renders audit events for admins", async () => {
    vi.mocked(authorizeCmsAdminRequest).mockResolvedValue({
      kind: "authorized",
      profile: {
        id: "admin-1",
        fullName: "Admin",
        role: "admin",
        isActive: true,
      },
    });
    vi.mocked(listAuditEvents).mockResolvedValue({
      ok: true,
      result: {
        items: [
          {
            eventId: "10000000-0000-4000-8000-000000000001",
            occurredAt: "2026-08-23T10:00:00.000Z",
            occurredAtLabel: "23 Aug 2026, 17:00",
            actorId: "20000000-0000-4000-8000-000000000001",
            actorName: "Admin User",
            entityType: "category",
            entityId: "30000000-0000-4000-8000-000000000001",
            action: "create",
            metadata: {
              slug: "shuttles",
              name: "Shuttles",
              is_active: true,
            },
            summary: "Category Shuttles: Created",
          },
        ],
        hasMore: false,
        nextCursor: null,
        query: parseAuditExplorerQuery({}),
        hasActiveFilters: false,
      },
    });

    render(await AuditPage({ searchParams: Promise.resolve({}) }));

    expect(
      screen.getByRole("heading", { name: /privileged audit trail/i }),
    ).toBeInTheDocument();
    expect(screen.getByText(/Category Shuttles: Created/i)).toBeInTheDocument();
  });
});
