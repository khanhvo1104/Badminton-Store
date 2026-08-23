"use client";

import { useActionState } from "react";
import { useFormStatus } from "react-dom";

import { updateStaffMember } from "@/features/staff/actions/update-staff-member";
import { INITIAL_STAFF_MUTATION_STATE } from "@/features/staff/form-state";
import type { StaffListItem } from "@/features/staff/types";

type StaffMemberActionsProps = {
  item: StaffListItem;
  isSelf: boolean;
};

export function StaffMemberActions({ item, isSelf }: StaffMemberActionsProps) {
  const [state, formAction] = useActionState(
    updateStaffMember.bind(null, item.profileId),
    INITIAL_STAFF_MUTATION_STATE,
  );

  const nextActive = !item.isActive;
  const nextRole = item.role === "admin" ? "staff" : "admin";
  const canToggleActive = !isSelf || item.isActive;
  const canChangeRole = !(isSelf && item.role === "admin");

  return (
    <div className="space-y-3">
      <form action={formAction} className="flex flex-wrap items-end gap-3">
        <input type="hidden" name="confirmed" value="yes" />

        {canToggleActive ? (
          <MutationButton
            name="is_active"
            value={nextActive ? "true" : "false"}
          >
            {nextActive ? "Activate" : "Deactivate"}
          </MutationButton>
        ) : null}

        {canChangeRole ? (
          <MutationButton name="role" value={nextRole}>
            {item.role === "admin" ? "Demote to staff" : "Promote to admin"}
          </MutationButton>
        ) : null}
      </form>

      {isSelf ? (
        <p className="text-xs text-slate-400">
          You cannot deactivate or demote your own admin account here.
        </p>
      ) : null}

      <p
        aria-live="polite"
        role={state.status === "error" ? "alert" : "status"}
        className="min-h-5 text-xs text-rose-300"
      >
        {state.message}
      </p>
    </div>
  );
}

function MutationButton({
  name,
  value,
  children,
}: {
  name: string;
  value: string;
  children: React.ReactNode;
}) {
  const { pending } = useFormStatus();

  return (
    <button
      type="submit"
      name={name}
      value={value}
      disabled={pending}
      className="inline-flex rounded-full border border-white/15 px-3 py-2 text-xs font-semibold uppercase tracking-[0.15em] text-white transition hover:border-white/30 hover:bg-white/5 disabled:cursor-not-allowed disabled:opacity-60 focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-emerald-200"
    >
      {children}
    </button>
  );
}
