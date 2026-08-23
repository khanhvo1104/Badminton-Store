import { beforeEach, describe, expect, it, vi } from "vitest";

const requireStaffAdminActionAuth = vi.hoisted(() => vi.fn());
const redirect = vi.hoisted(() => vi.fn());

vi.mock("next/navigation", () => ({
  redirect,
}));

vi.mock("@/features/staff/action-utils", async () => {
  const actual = await vi.importActual<
    typeof import("@/features/staff/action-utils")
  >("@/features/staff/action-utils");
  return {
    ...actual,
    requireStaffAdminActionAuth,
  };
});

import { updateStaffMember } from "@/features/staff/actions/update-staff-member";
import {
  readOptionalActive,
  readOptionalRole,
} from "@/features/staff/actions/staff-mutation-parsers";
import { STAFF_GENERIC_FAILURE_MESSAGE } from "@/features/staff/constants";
import { INITIAL_STAFF_MUTATION_STATE } from "@/features/staff/form-state";

const STAFF_ID = "a4100000-0000-4000-8000-000000000103";

function buildFormData(values: Record<string, string>): FormData {
  const formData = new FormData();
  for (const [key, value] of Object.entries(values)) {
    formData.set(key, value);
  }
  return formData;
}

describe("staff mutation parsers", () => {
  it("accepts absent fields as unchanged", () => {
    expect(readOptionalRole(null)).toBeNull();
    expect(readOptionalActive(null)).toBeNull();
  });

  it("rejects malformed role and active values", () => {
    expect(readOptionalRole("superuser")).toBeUndefined();
    expect(readOptionalActive("maybe")).toBeUndefined();
    expect(
      readOptionalActive(123 as unknown as FormDataEntryValue),
    ).toBeUndefined();
  });

  it("accepts valid role and active values", () => {
    expect(readOptionalRole("staff")).toBe("staff");
    expect(readOptionalRole("admin")).toBe("admin");
    expect(readOptionalActive("true")).toBe(true);
    expect(readOptionalActive("false")).toBe(false);
  });
});

describe("updateStaffMember", () => {
  beforeEach(() => {
    vi.clearAllMocks();
    redirect.mockImplementation((url: string) => {
      throw new Error(`NEXT_REDIRECT:${url}`);
    });
    requireStaffAdminActionAuth.mockResolvedValue({
      ok: true,
      actorId: "a4100000-0000-4000-8000-000000000101",
      supabase: { rpc: vi.fn() },
    });
  });

  it("rejects malformed role before calling the RPC", async () => {
    const rpc = vi.fn();
    requireStaffAdminActionAuth.mockResolvedValue({
      ok: true,
      actorId: "a4100000-0000-4000-8000-000000000101",
      supabase: { rpc },
    });

    const result = await updateStaffMember(
      STAFF_ID,
      INITIAL_STAFF_MUTATION_STATE,
      buildFormData({
        confirmed: "1",
        role: "superuser",
      }),
    );

    expect(result.status).toBe("error");
    expect(result.message).toBe(STAFF_GENERIC_FAILURE_MESSAGE);
    expect(rpc).not.toHaveBeenCalled();
  });

  it("rejects malformed active flag before calling the RPC", async () => {
    const rpc = vi.fn();
    requireStaffAdminActionAuth.mockResolvedValue({
      ok: true,
      actorId: "a4100000-0000-4000-8000-000000000101",
      supabase: { rpc },
    });

    const result = await updateStaffMember(
      STAFF_ID,
      INITIAL_STAFF_MUTATION_STATE,
      buildFormData({
        confirmed: "1",
        is_active: "maybe",
      }),
    );

    expect(result.status).toBe("error");
    expect(result.message).toBe(STAFF_GENERIC_FAILURE_MESSAGE);
    expect(rpc).not.toHaveBeenCalled();
  });
});
