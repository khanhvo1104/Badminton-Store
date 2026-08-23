import {
  FINALIZE_CMS_STAFF_INVITATION_RPC,
  GENERIC_FAILURE_MESSAGE,
} from "./invite-helpers.ts";

export type InviteAdminClient = {
  auth: {
    admin: {
      inviteUserByEmail: (
        email: string,
        options: { redirectTo: string; data?: { full_name: string } },
      ) => Promise<{ data: { user?: { id?: string } | null } | null; error: unknown }>;
      deleteUser: (userId: string) => Promise<{ error: unknown }>;
    };
  };
  rpc: (
    fn: typeof FINALIZE_CMS_STAFF_INVITATION_RPC,
    args: Record<string, unknown>,
  ) => PromiseLike<{ data: unknown; error: unknown }>;
};

export type FinalizeInvitedStaffInput = {
  adminClient: InviteAdminClient;
  actorId: string;
  invitedUserId: string;
  email: string;
  role: "staff" | "admin";
  fullName: string | null;
};

export type FinalizeInvitedStaffResult =
  | { ok: true; profileId: string }
  | { ok: false; compensated: boolean };

export async function finalizeInvitedStaff(
  input: FinalizeInvitedStaffInput,
): Promise<FinalizeInvitedStaffResult> {
  const { adminClient, actorId, invitedUserId, email, role, fullName } = input;

  const { data, error } = await adminClient.rpc(
    FINALIZE_CMS_STAFF_INVITATION_RPC,
    {
      p_actor_id: actorId,
      p_target_id: invitedUserId,
      p_role: role,
      p_target_email: email,
      p_full_name: fullName,
    },
  );

  if (error || typeof data !== "string" || data !== invitedUserId) {
    const deleteResult = await adminClient.auth.admin.deleteUser(invitedUserId);
    return {
      ok: false,
      compensated: !deleteResult.error,
    };
  }

  return { ok: true, profileId: invitedUserId };
}

export function finalizeFailureMessage(result: FinalizeInvitedStaffResult): string {
  void result;
  return GENERIC_FAILURE_MESSAGE;
}
