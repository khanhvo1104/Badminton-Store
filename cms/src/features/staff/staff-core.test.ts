import { describe, expect, it, vi } from "vitest";

vi.mock("@/lib/auth/authorization", () => ({
  authorizeCmsAdminRequest: vi.fn(),
}));

import {
  LIST_CMS_STAFF_RPC,
  STAFF_AUTH_DENIED_MESSAGE,
  STAFF_LOAD_FAILURE_MESSAGE,
} from "@/features/staff/constants";
import { assertNoProviderLeak } from "@/features/staff/errors";
import {
  mapCmsStaffRpcRow,
  mapStaffListItem,
  readUpdatedStaffProfileId,
} from "@/features/staff/mappers";
import { listStaffMembers } from "@/features/staff/queries";
import {
  getStaffExplorerRpcArgs,
  parseStaffExplorerQuery,
  staffExplorerHasActiveFilters,
} from "@/features/staff/validation";
import { authorizeCmsAdminRequest } from "@/lib/auth/authorization";

describe("staff validation", () => {
  it("bounds pagination and normalizes filters", () => {
    const query = parseStaffExplorerQuery({
      q: "  alex  ",
      role: "admin",
      active: "inactive",
      sort: "created_desc",
      page: "2",
      pageSize: "999",
    });

    expect(query.search).toBe("alex");
    expect(query.role).toBe("admin");
    expect(query.active).toBe("inactive");
    expect(query.sort).toBe("created_desc");
    expect(query.pagination.page).toBe(2);
    expect(query.pagination.pageSize).toBe(50);
    expect(staffExplorerHasActiveFilters(query)).toBe(true);
  });

  it("builds bounded RPC args", () => {
    const query = parseStaffExplorerQuery({});
    expect(getStaffExplorerRpcArgs(query)).toEqual({
      p_search: "",
      p_role: "all",
      p_active: "all",
      p_sort: "name_asc",
      p_offset: 0,
      p_limit: 20,
    });
  });
});

describe("staff mappers", () => {
  it("maps RPC rows without leaking extra fields", () => {
    const row = mapCmsStaffRpcRow({
      profile_id: "11111111-1111-4111-8111-111111111111",
      full_name: "Alex Coach",
      email: "alex@example.invalid",
      role: "staff",
      is_active: true,
      created_at: "2026-01-01T00:00:00.000Z",
      filtered_count: 1,
    });

    expect(row).not.toBeNull();
    const item = mapStaffListItem({
      ...row!,
      profile_id: row!.profile_id!,
      email: row!.email!,
    });
    expect(item?.email).toBe("alex@example.invalid");
    expect(
      readUpdatedStaffProfileId(
        "11111111-1111-4111-8111-111111111111",
        "11111111-1111-4111-8111-111111111111",
      ),
    ).toBe("11111111-1111-4111-8111-111111111111");
  });
});

describe("listStaffMembers", () => {
  it("denies non-admin callers before RPC", async () => {
    vi.mocked(authorizeCmsAdminRequest).mockResolvedValue({
      kind: "unauthorized",
    });
    const rpc = vi.fn();

    const result = await listStaffMembers({
      supabase: { auth: { getClaims: vi.fn() }, rpc },
      query: parseStaffExplorerQuery({}),
    });

    expect(result.ok).toBe(false);
    if (!result.ok) {
      expect(result.message).toBe(STAFF_AUTH_DENIED_MESSAGE);
      expect(assertNoProviderLeak(result.message)).toBe(true);
    }
    expect(rpc).not.toHaveBeenCalled();
  });

  it("loads admin staff directory rows", async () => {
    vi.mocked(authorizeCmsAdminRequest).mockResolvedValue({
      kind: "authorized",
      profile: {
        id: "admin-1",
        fullName: "Admin",
        role: "admin",
        isActive: true,
      },
    });
    const rpc = vi.fn().mockResolvedValue({
      data: [
        {
          profile_id: "staff-1",
          full_name: "Alex Coach",
          email: "alex@example.invalid",
          role: "staff",
          is_active: true,
          created_at: "2026-01-01T00:00:00.000Z",
          filtered_count: 1,
        },
      ],
      error: null,
    });

    const result = await listStaffMembers({
      supabase: { auth: { getClaims: vi.fn() }, rpc },
      query: parseStaffExplorerQuery({}),
    });

    expect(result.ok).toBe(true);
    expect(rpc).toHaveBeenCalledWith(LIST_CMS_STAFF_RPC, expect.any(Object));
    if (result.ok) {
      expect(result.result.items).toHaveLength(1);
    }
  });

  it("sanitizes provider failures", async () => {
    vi.mocked(authorizeCmsAdminRequest).mockResolvedValue({
      kind: "authorized",
      profile: {
        id: "admin-1",
        fullName: "Admin",
        role: "admin",
        isActive: true,
      },
    });

    const result = await listStaffMembers({
      supabase: {
        auth: { getClaims: vi.fn() },
        rpc: vi.fn().mockResolvedValue({
          data: null,
          error: { message: "postgrest failure" },
        }),
      },
      query: parseStaffExplorerQuery({}),
    });

    expect(result.ok).toBe(false);
    if (!result.ok) {
      expect(result.message).toBe(STAFF_LOAD_FAILURE_MESSAGE);
    }
  });
});
