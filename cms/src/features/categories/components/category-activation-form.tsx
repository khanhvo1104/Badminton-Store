"use client";

import { useActionState, useId, useRef, useState } from "react";
import { useFormStatus } from "react-dom";

import { ConfirmationDialog } from "@/components/ui/confirmation-dialog";
import { setCategoryActive } from "@/features/categories/actions/set-category-active";
import { INITIAL_CATEGORY_ACTIVATION_STATE } from "@/features/categories/category-form-state";

type CategoryActivationFormProps = {
  categoryId: string;
  isActive: boolean;
  categoryName: string;
};

export function CategoryActivationForm({
  categoryId,
  isActive,
  categoryName,
}: CategoryActivationFormProps) {
  const [state, formAction] = useActionState(
    setCategoryActive,
    INITIAL_CATEGORY_ACTIVATION_STATE,
  );
  const [dialogOpen, setDialogOpen] = useState(false);
  const formRef = useRef<HTMLFormElement>(null);
  const triggerRef = useRef<HTMLButtonElement>(null);
  const confirmFieldId = useId();
  const nextActive = !isActive;

  return (
    <section
      aria-labelledby="category-activation-heading"
      className="rounded-3xl border border-white/10 bg-slate-950/40 p-6"
    >
      <h2
        id="category-activation-heading"
        className="text-lg font-semibold text-white"
      >
        Activation
      </h2>
      <p className="mt-2 text-sm leading-7 text-slate-300">
        {isActive
          ? "This category is active and can appear for public catalog users."
          : "This category is inactive. Authorized CMS users can still see it here."}
      </p>

      <form ref={formRef} action={formAction} className="mt-4 space-y-4">
        <input type="hidden" name="id" value={categoryId} />
        <input
          type="hidden"
          name="is_active"
          value={nextActive ? "true" : "false"}
        />

        <div className="flex items-start gap-3">
          <input
            id={confirmFieldId}
            name="confirmed"
            type="checkbox"
            value="yes"
            required
            className="mt-1 h-4 w-4 rounded border-white/20 bg-slate-950 text-emerald-300 focus:ring-emerald-300/40"
          />
          <label htmlFor={confirmFieldId} className="text-sm text-slate-200">
            I confirm I want to {nextActive ? "activate" : "deactivate"} “
            {categoryName}”.
          </label>
        </div>

        <p
          aria-live="polite"
          role={state.status === "error" ? "alert" : "status"}
          className="min-h-6 text-sm text-rose-300"
        >
          {state.message}
        </p>

        <div className="flex flex-wrap gap-3">
          <button
            ref={triggerRef}
            type="button"
            onClick={() => setDialogOpen(true)}
            className="rounded-full border border-white/15 px-5 py-3 text-sm font-semibold text-white transition hover:border-white/30 hover:bg-white/5 focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-emerald-200"
          >
            {nextActive ? "Activate category" : "Deactivate category"}
          </button>
          <noscript>
            <NoscriptSubmit nextActive={nextActive} />
          </noscript>
        </div>
      </form>

      <ConfirmationDialog
        open={dialogOpen}
        title={nextActive ? "Activate category?" : "Deactivate category?"}
        description={
          nextActive
            ? `Activate “${categoryName}” so it can appear for public catalog users.`
            : `Deactivate “${categoryName}”? It will stay visible to CMS staff and remain hidden from public users.`
        }
        confirmLabel={nextActive ? "Activate" : "Deactivate"}
        cancelLabel="Cancel"
        returnFocusRef={triggerRef}
        onCancel={() => setDialogOpen(false)}
        onConfirm={() => {
          const form = formRef.current;
          if (!form) return;
          const checkbox = form.elements.namedItem(
            "confirmed",
          ) as HTMLInputElement | null;
          if (checkbox) checkbox.checked = true;
          setDialogOpen(false);
          form.requestSubmit();
        }}
      />
    </section>
  );
}

function NoscriptSubmit({ nextActive }: { nextActive: boolean }) {
  const { pending } = useFormStatus();
  return (
    <button
      type="submit"
      disabled={pending}
      aria-disabled={pending}
      className="rounded-full bg-emerald-300 px-5 py-3 text-sm font-semibold text-slate-950 transition hover:bg-emerald-200 focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-emerald-200 disabled:cursor-not-allowed disabled:opacity-70"
    >
      {pending
        ? "Saving..."
        : nextActive
          ? "Confirm activate"
          : "Confirm deactivate"}
    </button>
  );
}
