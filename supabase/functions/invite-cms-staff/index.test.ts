import { assertEquals } from "jsr:@std/assert@1";

import { finalizeInvitedStaff } from "./invite-flow.ts";
import {
  buildInviteRedirectTo,
  DUPLICATE_MESSAGE,
  GENERIC_FAILURE_MESSAGE,
  mapInviteError,
  RATE_LIMIT_MESSAGE,
  readEmail,
  readFullName,
  readRole,
} from "./invite-helpers.ts";

Deno.test("readEmail normalizes and validates addresses", () => {
  assertEquals(readEmail(" Staff@Example.COM "), "staff@example.com");
  assertEquals(readEmail("not-an-email"), null);
  assertEquals(readEmail(""), null);
});

Deno.test("readRole accepts staff and admin only", () => {
  assertEquals(readRole("staff"), "staff");
  assertEquals(readRole("admin"), "admin");
  assertEquals(readRole("customer"), null);
});

Deno.test("readFullName trims and bounds length", () => {
  assertEquals(readFullName("  Alex   Coach  "), "Alex Coach");
  assertEquals(readFullName("x".repeat(121)), null);
});

Deno.test("buildInviteRedirectTo uses CMS callback contract", () => {
  assertEquals(
    buildInviteRedirectTo("http://localhost:3000"),
    "http://localhost:3000/auth/callback?next=%2Fupdate-password",
  );
  assertEquals(buildInviteRedirectTo("not-a-url"), null);
});

Deno.test("mapInviteError sanitizes provider failures", () => {
  assertEquals(
    mapInviteError({ status: 429, message: "email rate limit exceeded" }),
    RATE_LIMIT_MESSAGE,
  );
  assertEquals(
    mapInviteError({ message: "User already registered" }),
    DUPLICATE_MESSAGE,
  );
  assertEquals(mapInviteError({ message: "unexpected" }), GENERIC_FAILURE_MESSAGE);
});

Deno.test("finalizeInvitedStaff compensates when RPC finalization fails", async () => {
  let deleteCalled = false;
  const adminClient = {
    rpc: async () => ({ data: null, error: { message: "invalid request" } }),
    auth: {
      admin: {
        inviteUserByEmail: async () => ({ data: { user: { id: "user-1" } }, error: null }),
        deleteUser: async (userId: string) => {
          deleteCalled = userId === "user-1";
          return { error: null };
        },
      },
    },
  };

  const result = await finalizeInvitedStaff({
    adminClient,
    actorId: "admin-1",
    invitedUserId: "user-1",
    email: "staff@example.invalid",
    role: "staff",
    fullName: null,
  });

  assertEquals(result.ok, false);
  if (!result.ok) {
    assertEquals(result.compensated, true);
  }
  assertEquals(deleteCalled, true);
});

Deno.test("finalizeInvitedStaff succeeds without compensation", async () => {
  let deleteCalled = false;
  const adminClient = {
    rpc: async () => ({ data: "user-2", error: null }),
    auth: {
      admin: {
        inviteUserByEmail: async () => ({ data: { user: { id: "user-2" } }, error: null }),
        deleteUser: async () => {
          deleteCalled = true;
          return { error: null };
        },
      },
    },
  };

  const result = await finalizeInvitedStaff({
    adminClient,
    actorId: "admin-1",
    invitedUserId: "user-2",
    email: "staff@example.invalid",
    role: "admin",
    fullName: "Alex Coach",
  });

  assertEquals(result, { ok: true, profileId: "user-2" });
  assertEquals(deleteCalled, false);
});
