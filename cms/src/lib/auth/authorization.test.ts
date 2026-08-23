import { describe, expect, it, vi } from "vitest";

import {
  authorizeCmsAdminRequest,
  authorizeCmsRequest,
  CMS_PROFILE_COLUMNS,
  getVerifiedSubject,
} from "@/lib/auth/authorization";

function createSupabaseDouble(options: {
  claimsError?: unknown;
  claimsReject?: unknown;
  claimsSub?: unknown;
  claimsAmr?: unknown;
  profileData?: unknown;
  profileError?: unknown;
  profileReject?: unknown;
}) {
  const maybeSingle =
    options.profileReject === undefined
      ? vi.fn().mockResolvedValue({
          data: options.profileData ?? null,
          error: options.profileError ?? null,
        })
      : vi.fn().mockRejectedValue(options.profileReject);

  const eq = vi.fn().mockReturnValue({ maybeSingle });
  const select = vi.fn().mockReturnValue({ eq });
  const from = vi.fn().mockReturnValue({ select });

  const getClaims =
    options.claimsReject === undefined
      ? vi.fn().mockResolvedValue({
          data:
            options.claimsError === undefined
              ? {
                  claims: {
                    sub: options.claimsSub,
                    ...(options.claimsAmr === undefined
                      ? {}
                      : { amr: options.claimsAmr }),
                  },
                }
              : null,
          error: options.claimsError ?? null,
        })
      : vi.fn().mockRejectedValue(options.claimsReject);

  return {
    client: {
      auth: {
        getClaims,
      },
      from,
    },
    spies: {
      from,
      select,
      eq,
      maybeSingle,
    },
  };
}

describe("getVerifiedSubject", () => {
  it("returns the verified subject when claims are present", async () => {
    const { client } = createSupabaseDouble({ claimsSub: "user-123" });

    await expect(getVerifiedSubject(client)).resolves.toBe("user-123");
  });

  it("returns null when claims fail verification", async () => {
    const { client } = createSupabaseDouble({
      claimsError: new Error("expired token"),
    });

    await expect(getVerifiedSubject(client)).resolves.toBeNull();
  });

  it("returns null when getClaims rejects", async () => {
    const { client } = createSupabaseDouble({
      claimsReject: new Error("network down: secrets leaked would be bad"),
    });

    await expect(getVerifiedSubject(client)).resolves.toBeNull();
  });
});

describe("authorizeCmsRequest", () => {
  it("returns anonymous when claims are missing", async () => {
    const { client, spies } = createSupabaseDouble({ claimsSub: "" });

    await expect(authorizeCmsRequest(client)).resolves.toEqual({
      kind: "anonymous",
    });
    expect(spies.from).not.toHaveBeenCalled();
  });

  it("authorizes an active staff profile", async () => {
    const { client, spies } = createSupabaseDouble({
      claimsSub: "staff-1",
      profileData: {
        id: "staff-1",
        full_name: "Alex Coach",
        role: "staff",
        is_active: true,
      },
    });

    await expect(authorizeCmsRequest(client)).resolves.toEqual({
      kind: "authorized",
      profile: {
        id: "staff-1",
        fullName: "Alex Coach",
        role: "staff",
        isActive: true,
      },
    });
    expect(spies.from).toHaveBeenCalledWith("profiles");
    expect(spies.select).toHaveBeenCalledWith(CMS_PROFILE_COLUMNS);
    expect(spies.eq).toHaveBeenCalledWith("id", "staff-1");
  });

  it("authorizes an active admin profile", async () => {
    const { client } = createSupabaseDouble({
      claimsSub: "admin-1",
      profileData: {
        id: "admin-1",
        full_name: null,
        role: "admin",
        is_active: true,
      },
    });

    await expect(authorizeCmsRequest(client)).resolves.toEqual({
      kind: "authorized",
      profile: {
        id: "admin-1",
        fullName: null,
        role: "admin",
        isActive: true,
      },
    });
  });

  it("requires admin role for admin-only authorization", async () => {
    const staffClient = createSupabaseDouble({
      claimsSub: "staff-1",
      profileData: {
        id: "staff-1",
        full_name: "Staff",
        role: "staff",
        is_active: true,
      },
    }).client;

    await expect(authorizeCmsAdminRequest(staffClient)).resolves.toEqual({
      kind: "unauthorized",
    });

    const adminClient = createSupabaseDouble({
      claimsSub: "admin-1",
      profileData: {
        id: "admin-1",
        full_name: "Admin",
        role: "admin",
        is_active: true,
      },
    }).client;

    await expect(authorizeCmsAdminRequest(adminClient)).resolves.toEqual({
      kind: "authorized",
      profile: {
        id: "admin-1",
        fullName: "Admin",
        role: "admin",
        isActive: true,
      },
    });
  });

  it("collapses customer profiles to unauthorized", async () => {
    const { client } = createSupabaseDouble({
      claimsSub: "customer-1",
      profileData: {
        id: "customer-1",
        full_name: "Customer",
        role: "customer",
        is_active: true,
      },
    });

    await expect(authorizeCmsRequest(client)).resolves.toEqual({
      kind: "unauthorized",
    });
  });

  it("does not treat a recovery session as CMS dashboard authorization", async () => {
    const { client } = createSupabaseDouble({
      claimsSub: "customer-1",
      claimsAmr: [{ method: "recovery", timestamp: 1 }],
      profileData: {
        id: "customer-1",
        full_name: "Customer",
        role: "customer",
        is_active: true,
      },
    });

    await expect(authorizeCmsRequest(client)).resolves.toEqual({
      kind: "unauthorized",
    });
  });

  it("rejects an active staff recovery session until a normal sign-in", async () => {
    const { client, spies } = createSupabaseDouble({
      claimsSub: "staff-1",
      claimsAmr: [{ method: "recovery", timestamp: 1 }],
      profileData: {
        id: "staff-1",
        full_name: "Alex Coach",
        role: "staff",
        is_active: true,
      },
    });

    await expect(authorizeCmsRequest(client)).resolves.toEqual({
      kind: "unauthorized",
    });
    expect(spies.from).not.toHaveBeenCalled();
  });

  it("rejects an active admin recovery session until a normal sign-in", async () => {
    const { client, spies } = createSupabaseDouble({
      claimsSub: "admin-1",
      claimsAmr: [{ method: "recovery", timestamp: 1715766000 }],
      profileData: {
        id: "admin-1",
        full_name: null,
        role: "admin",
        is_active: true,
      },
    });

    await expect(authorizeCmsRequest(client)).resolves.toEqual({
      kind: "unauthorized",
    });
    expect(spies.from).not.toHaveBeenCalled();
  });

  it("collapses unsupported roles to unauthorized", async () => {
    const { client } = createSupabaseDouble({
      claimsSub: "contractor-1",
      profileData: {
        id: "contractor-1",
        full_name: "Vendor",
        role: "contractor",
        is_active: true,
      },
    });

    await expect(authorizeCmsRequest(client)).resolves.toEqual({
      kind: "unauthorized",
    });
  });

  it("collapses inactive profiles to unauthorized", async () => {
    const { client } = createSupabaseDouble({
      claimsSub: "staff-2",
      profileData: {
        id: "staff-2",
        full_name: "Inactive",
        role: "staff",
        is_active: false,
      },
    });

    await expect(authorizeCmsRequest(client)).resolves.toEqual({
      kind: "unauthorized",
    });
  });

  it("collapses missing profiles to unauthorized", async () => {
    const { client } = createSupabaseDouble({
      claimsSub: "missing-1",
      profileData: null,
    });

    await expect(authorizeCmsRequest(client)).resolves.toEqual({
      kind: "unauthorized",
    });
  });

  it("collapses malformed profiles to unauthorized", async () => {
    const { client } = createSupabaseDouble({
      claimsSub: "staff-3",
      profileData: {
        id: "different-user",
        full_name: "Wrong User",
        role: "staff",
        is_active: true,
      },
    });

    await expect(authorizeCmsRequest(client)).resolves.toEqual({
      kind: "unauthorized",
    });
  });

  it("collapses profile query failures to unauthorized", async () => {
    const { client } = createSupabaseDouble({
      claimsSub: "staff-4",
      profileError: new Error("db unavailable"),
    });

    await expect(authorizeCmsRequest(client)).resolves.toEqual({
      kind: "unauthorized",
    });
  });

  it("collapses rejected getClaims to anonymous", async () => {
    const { client, spies } = createSupabaseDouble({
      claimsReject: new Error("JWT verification exploded"),
    });

    await expect(authorizeCmsRequest(client)).resolves.toEqual({
      kind: "anonymous",
    });
    expect(spies.from).not.toHaveBeenCalled();
  });

  it("collapses rejected profile queries to unauthorized", async () => {
    const { client } = createSupabaseDouble({
      claimsSub: "staff-5",
      profileReject: new Error("connection reset: internal host details"),
    });

    await expect(authorizeCmsRequest(client)).resolves.toEqual({
      kind: "unauthorized",
    });
  });
});
