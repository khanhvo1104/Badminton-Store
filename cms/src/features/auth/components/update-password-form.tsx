"use client";

import { useActionState } from "react";
import { useFormStatus } from "react-dom";

import { updatePassword } from "@/features/auth/actions/update-password";
import { INITIAL_UPDATE_PASSWORD_FORM_STATE } from "@/features/auth/update-password-form-state";

export function UpdatePasswordForm() {
  const [state, formAction] = useActionState(
    updatePassword,
    INITIAL_UPDATE_PASSWORD_FORM_STATE,
  );

  return (
    <form action={formAction} className="mt-8 space-y-6" noValidate>
      <div className="space-y-2">
        <label
          htmlFor="password"
          className="text-sm font-medium text-slate-100"
        >
          New password
        </label>
        <input
          id="password"
          name="password"
          type="password"
          autoComplete="new-password"
          required
          minLength={12}
          className="w-full rounded-2xl border border-white/10 bg-slate-950/70 px-4 py-3 text-base text-white outline-none transition placeholder:text-slate-400 focus:border-emerald-300 focus:ring-2 focus:ring-emerald-300/30"
        />
      </div>

      <div className="space-y-2">
        <label
          htmlFor="confirmPassword"
          className="text-sm font-medium text-slate-100"
        >
          Confirm password
        </label>
        <input
          id="confirmPassword"
          name="confirmPassword"
          type="password"
          autoComplete="new-password"
          required
          minLength={12}
          className="w-full rounded-2xl border border-white/10 bg-slate-950/70 px-4 py-3 text-base text-white outline-none transition placeholder:text-slate-400 focus:border-emerald-300 focus:ring-2 focus:ring-emerald-300/30"
        />
      </div>

      <p
        aria-live="polite"
        role={state.errorMessage ? "alert" : "status"}
        className="min-h-6 text-sm text-rose-300"
      >
        {state.errorMessage}
      </p>

      <UpdatePasswordSubmitButton />
    </form>
  );
}

function UpdatePasswordSubmitButton() {
  const { pending } = useFormStatus();

  return (
    <button
      type="submit"
      disabled={pending}
      aria-disabled={pending}
      className="inline-flex w-full items-center justify-center rounded-full bg-emerald-300 px-5 py-3 text-sm font-semibold text-slate-950 transition hover:bg-emerald-200 focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-emerald-200 disabled:cursor-not-allowed disabled:opacity-70"
    >
      {pending ? "Updating password..." : "Update password"}
    </button>
  );
}
