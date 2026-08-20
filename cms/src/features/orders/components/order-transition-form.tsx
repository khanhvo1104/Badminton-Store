"use client";

import {
  useActionState,
  useMemo,
  useRef,
  useState,
  type ReactNode,
  type RefObject,
} from "react";
import { useFormStatus } from "react-dom";

import { ConfirmationDialog } from "@/components/ui/confirmation-dialog";
import { transitionOrderStatus } from "@/features/orders/actions/transition-order-status";
import {
  ORDERS_NOTE_MAX_LENGTH,
  ORDER_STATUS_LABELS,
} from "@/features/orders/constants";
import { INITIAL_ORDER_TRANSITION_FORM_STATE } from "@/features/orders/transition-form-state";
import type {
  OrderStatus,
  OrderTransitionFormState,
} from "@/features/orders/types";

type OrderTransitionFormProps = {
  orderId: string;
  currentStatus: OrderStatus;
  nextStatuses: OrderStatus[];
  initialState?: OrderTransitionFormState;
};

export function OrderTransitionForm({
  orderId,
  currentStatus,
  nextStatuses,
  initialState,
}: OrderTransitionFormProps) {
  const resolvedInitialState =
    initialState ?? INITIAL_ORDER_TRANSITION_FORM_STATE;
  const action = useMemo(
    () => transitionOrderStatus.bind(null, orderId),
    [orderId],
  );
  const [state, formAction] = useActionState(action, resolvedInitialState);
  const [dialogOpen, setDialogOpen] = useState(false);
  const [pendingStatus, setPendingStatus] = useState(
    state.values.toStatus || nextStatuses[0] || "",
  );
  const formRef = useRef<HTMLFormElement>(null);
  const triggerRef = useRef<HTMLButtonElement>(null);
  const confirmedInputRef = useRef<HTMLInputElement>(null);

  if (nextStatuses.length === 0) {
    return (
      <section
        aria-labelledby="transition-heading"
        className="space-y-3 rounded-3xl border border-white/10 bg-slate-900/60 p-5"
      >
        <h2
          id="transition-heading"
          className="text-lg font-semibold text-white"
        >
          Status transition
        </h2>
        <p className="text-sm text-slate-300">
          {ORDER_STATUS_LABELS[currentStatus]} is a terminal status. No further
          transitions are available.
        </p>
      </section>
    );
  }

  return (
    <section
      aria-labelledby="transition-heading"
      className="space-y-4 rounded-3xl border border-white/10 bg-slate-900/60 p-5"
    >
      <h2 id="transition-heading" className="text-lg font-semibold text-white">
        Status transition
      </h2>
      <p className="text-sm text-slate-300">
        Current status: {ORDER_STATUS_LABELS[currentStatus]}. Payment status is
        read-only.
      </p>

      <form
        ref={formRef}
        action={formAction}
        className="space-y-6"
        noValidate
        onSubmit={(event) => {
          if (confirmedInputRef.current?.value === "1") {
            return;
          }
          event.preventDefault();
          const form = event.currentTarget;
          const selected = new FormData(form).get("to_status");
          setPendingStatus(
            typeof selected === "string" && selected
              ? selected
              : nextStatuses[0] || "",
          );
          setDialogOpen(true);
        }}
      >
        <Field
          id="to_status"
          label="Next status"
          help="Only allowed transitions are listed. The server re-checks the live order status."
          error={state.fieldErrors.toStatus}
        >
          <select
            id="to_status"
            name="to_status"
            required
            defaultValue={state.values.toStatus || nextStatuses[0]}
            aria-describedby={describedBy(
              "to_status",
              state.fieldErrors.toStatus,
            )}
            aria-invalid={Boolean(state.fieldErrors.toStatus)}
            className={inputClassName}
          >
            {nextStatuses.map((status) => (
              <option key={status} value={status}>
                {ORDER_STATUS_LABELS[status]}
              </option>
            ))}
          </select>
        </Field>

        <Field
          id="note"
          label="Staff note (optional)"
          help="Bounded plain-text note stored with the status history entry."
          error={state.fieldErrors.note}
        >
          <textarea
            id="note"
            name="note"
            rows={3}
            maxLength={ORDERS_NOTE_MAX_LENGTH}
            defaultValue={state.values.note}
            aria-describedby={describedBy("note", state.fieldErrors.note)}
            aria-invalid={Boolean(state.fieldErrors.note)}
            className={inputClassName}
          />
        </Field>

        <input
          ref={confirmedInputRef}
          type="hidden"
          name="confirmed"
          defaultValue=""
        />

        {state.message ? (
          <p
            role="alert"
            className="rounded-2xl border border-rose-300/20 bg-rose-300/10 px-4 py-3 text-sm text-rose-100"
          >
            {state.message}
          </p>
        ) : null}
        {state.fieldErrors.confirmed ? (
          <p role="alert" className="text-sm text-rose-200">
            {state.fieldErrors.confirmed}
          </p>
        ) : null}

        <SubmitButton triggerRef={triggerRef} />
      </form>

      <ConfirmationDialog
        open={dialogOpen}
        title="Confirm order status change"
        description={`Change this order from ${ORDER_STATUS_LABELS[currentStatus]} to ${
          pendingStatus && pendingStatus in ORDER_STATUS_LABELS
            ? ORDER_STATUS_LABELS[pendingStatus as OrderStatus]
            : "the selected status"
        }? Inventory effects run atomically with this transition.`}
        confirmLabel="Confirm transition"
        cancelLabel="Keep editing"
        returnFocusRef={triggerRef}
        onCancel={() => setDialogOpen(false)}
        onConfirm={() => {
          if (!formRef.current || !confirmedInputRef.current) {
            setDialogOpen(false);
            return;
          }
          confirmedInputRef.current.value = "1";
          setDialogOpen(false);
          formRef.current.requestSubmit();
        }}
      />
    </section>
  );
}

function SubmitButton({
  triggerRef,
}: {
  triggerRef: RefObject<HTMLButtonElement | null>;
}) {
  const { pending } = useFormStatus();
  return (
    <button
      ref={triggerRef}
      type="submit"
      disabled={pending}
      className="rounded-full bg-emerald-300 px-5 py-3 text-sm font-semibold text-slate-950 transition hover:bg-emerald-200 focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-emerald-200 disabled:cursor-not-allowed disabled:opacity-60"
    >
      {pending ? "Updating…" : "Update status"}
    </button>
  );
}

function Field({
  id,
  label,
  help,
  error,
  children,
}: {
  id: string;
  label: string;
  help: string;
  error?: string;
  children: ReactNode;
}) {
  return (
    <div className="space-y-2">
      <label htmlFor={id} className="text-sm font-semibold text-white">
        {label}
      </label>
      {children}
      <p id={`${id}-help`} className="text-xs leading-6 text-slate-400">
        {help}
      </p>
      {error ? (
        <p id={`${id}-error`} role="alert" className="text-sm text-rose-200">
          {error}
        </p>
      ) : null}
    </div>
  );
}

function describedBy(id: string, error?: string): string {
  return error ? `${id}-help ${id}-error` : `${id}-help`;
}

const inputClassName =
  "w-full rounded-2xl border border-white/10 bg-slate-950 px-4 py-3 text-sm text-white outline-none transition focus:border-emerald-300/50";
