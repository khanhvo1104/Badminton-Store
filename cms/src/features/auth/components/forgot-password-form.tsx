"use client";

import Link from "next/link";
import { useActionState } from "react";
import { useFormStatus } from "react-dom";

import { requestPasswordReset } from "@/features/auth/actions/request-password-reset";
import { INITIAL_FORGOT_PASSWORD_FORM_STATE } from "@/features/auth/forgot-password-form-state";
import { CMS_LOGIN_PATH } from "@/lib/auth/authorization";

export function ForgotPasswordForm() {
  const [state, formAction] = useActionState(
    requestPasswordReset,
    INITIAL_FORGOT_PASSWORD_FORM_STATE,
  );

  return (
    <form action={formAction} className="mt-8 space-y-6" noValidate>
      <div className="space-y-2">
        <label htmlFor="email" className="text-sm font-medium text-slate-100">
          Email
        </label>
        <input
          id="email"
          name="email"
          type="email"
          autoComplete="email"
          required
          className="w-full rounded-2xl border border-white/10 bg-slate-950/70 px-4 py-3 text-base text-white outline-none transition placeholder:text-slate-400 focus:border-emerald-300 focus:ring-2 focus:ring-emerald-300/30"
        />
      </div>

      <p
        aria-live="polite"
        role={state.errorMessage ? "alert" : "status"}
        className={
          state.errorMessage
            ? "min-h-6 text-sm text-rose-300"
            : "min-h-6 text-sm text-emerald-200"
        }
      >
        {state.errorMessage ?? state.acknowledgement}
      </p>

      <ForgotPasswordSubmitButton />

      <p className="text-center text-sm text-slate-300">
        <Link
          href={CMS_LOGIN_PATH}
          className="font-semibold text-emerald-200 underline-offset-4 hover:underline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-emerald-200"
        >
          Back to sign in
        </Link>
      </p>
    </form>
  );
}

function ForgotPasswordSubmitButton() {
  const { pending } = useFormStatus();

  return (
    <button
      type="submit"
      disabled={pending}
      aria-disabled={pending}
      className="inline-flex w-full items-center justify-center rounded-full bg-emerald-300 px-5 py-3 text-sm font-semibold text-slate-950 transition hover:bg-emerald-200 focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-emerald-200 disabled:cursor-not-allowed disabled:opacity-70"
    >
      {pending ? "Sending recovery email..." : "Send recovery email"}
    </button>
  );
}
