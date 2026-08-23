"use client";

import { useActionState, useId } from "react";
import { useFormStatus } from "react-dom";

import { inviteStaffMember } from "@/features/staff/actions/invite-staff-member";
import { INITIAL_STAFF_INVITE_STATE } from "@/features/staff/form-state";

export function StaffInviteForm() {
  const [state, formAction] = useActionState(
    inviteStaffMember,
    INITIAL_STAFF_INVITE_STATE,
  );
  const emailId = useId();
  const fullNameId = useId();
  const roleId = useId();
  const confirmId = useId();

  return (
    <section
      aria-labelledby="staff-invite-heading"
      className="rounded-3xl border border-white/10 bg-slate-950/40 p-6"
    >
      <h2
        id="staff-invite-heading"
        className="text-lg font-semibold text-white"
      >
        Invite staff member
      </h2>
      <p className="mt-2 text-sm leading-7 text-slate-300">
        Invitations are sent through the trusted Edge Function boundary. The
        recipient sets a password from the email link before CMS access is
        granted.
      </p>

      <form action={formAction} className="mt-6 space-y-4">
        <div className="grid gap-4 md:grid-cols-2">
          <Field id={emailId} label="Email" error={state.fieldErrors.email}>
            <input
              id={emailId}
              name="email"
              type="email"
              required
              autoComplete="off"
              defaultValue={state.values.email}
              maxLength={254}
              className={inputClassName}
            />
          </Field>
          <Field
            id={fullNameId}
            label="Full name (optional)"
            error={state.fieldErrors.fullName}
          >
            <input
              id={fullNameId}
              name="fullName"
              type="text"
              defaultValue={state.values.fullName}
              maxLength={120}
              className={inputClassName}
            />
          </Field>
        </div>

        <Field id={roleId} label="Role" error={state.fieldErrors.role}>
          <select
            id={roleId}
            name="role"
            defaultValue={state.values.role}
            className={inputClassName}
          >
            <option value="staff">Staff</option>
            <option value="admin">Admin</option>
          </select>
        </Field>

        <div className="flex items-start gap-3">
          <input
            id={confirmId}
            name="confirmed"
            type="checkbox"
            value="yes"
            required
            className="mt-1 h-4 w-4 rounded border-white/20 bg-slate-950 text-emerald-300 focus:ring-emerald-300/40"
          />
          <label htmlFor={confirmId} className="text-sm text-slate-200">
            I confirm this invitation should be sent to a trusted operator.
          </label>
        </div>
        {state.fieldErrors.confirmed ? (
          <p className="text-sm text-rose-300">{state.fieldErrors.confirmed}</p>
        ) : null}

        <p
          aria-live="polite"
          role={state.status === "error" ? "alert" : "status"}
          className="min-h-6 text-sm text-rose-300"
        >
          {state.message}
        </p>

        <SubmitButton />
      </form>
    </section>
  );
}

function SubmitButton() {
  const { pending } = useFormStatus();
  return (
    <button
      type="submit"
      disabled={pending}
      className="inline-flex rounded-full bg-emerald-300 px-5 py-3 text-sm font-semibold text-slate-950 transition hover:bg-emerald-200 disabled:cursor-not-allowed disabled:opacity-60 focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-emerald-200"
    >
      {pending ? "Sending invitation…" : "Send invitation"}
    </button>
  );
}

function Field({
  id,
  label,
  error,
  children,
}: {
  id: string;
  label: string;
  error?: string;
  children: React.ReactNode;
}) {
  return (
    <div className="space-y-2">
      <label htmlFor={id} className="text-sm font-medium text-slate-200">
        {label}
      </label>
      {children}
      {error ? <p className="text-sm text-rose-300">{error}</p> : null}
    </div>
  );
}

const inputClassName =
  "w-full rounded-2xl border border-white/10 bg-slate-950/80 px-4 py-3 text-sm text-white placeholder:text-slate-500 focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-emerald-200";
