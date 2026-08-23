import { beforeEach, describe, expect, it, vi } from "vitest";

const authorizeCmsAdminRequest = vi.hoisted(() => vi.fn());

vi.mock("@/lib/auth/authorization", async () => {
  const actual = await vi.importActual<
    typeof import("@/lib/auth/authorization")
  >("@/lib/auth/authorization");
  return { ...actual, authorizeCmsAdminRequest };
});

import { listAuditEvents } from "@/features/audit/queries";
import { parseAuditExplorerQuery } from "@/features/audit/validation";

describe("listAuditEvents", () => {
  beforeEach(() => {
    authorizeCmsAdminRequest.mockReset();
  });

  it("denies non-admin callers before RPC", async () => {
    authorizeCmsAdminRequest.mockResolvedValue({ kind: "unauthorized" });
    const rpc = vi.fn();

    const result = await listAuditEvents({
      supabase: {
        auth: { getClaims: vi.fn() },
        rpc,
      },
      query: parseAuditExplorerQuery({}),
    });

    expect(result.ok).toBe(false);
    expect(rpc).not.toHaveBeenCalled();
  });
});
