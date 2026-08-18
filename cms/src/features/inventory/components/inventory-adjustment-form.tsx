"use client";

import { useActionState, useMemo, type ReactNode } from "react";
import { useFormStatus } from "react-dom";

import { adjustInventory } from "@/features/inventory/actions/adjust-inventory";
import { INITIAL_INVENTORY_FORM_STATE } from "@/features/inventory/adjustment-form-state";
import {
  INVENTORY_NOTE_MAX_LENGTH,
  INVENTORY_OPERATION_LABELS,
  INVENTORY_OPERATIONS,
  INVENTORY_REASON_LABELS,
  INVENTORY_REASONS,
} from "@/features/inventory/constants";
import type { InventoryFormState } from "@/features/inventory/types";

type InventoryAdjustmentFormProps = {
  variantId: string;
  initialAllowBackorder: boolean | null;
  initialState?: InventoryFormState;
};

export function InventoryAdjustmentForm({
  variantId,
  initialAllowBackorder,
  initialState,
}: InventoryAdjustmentFormProps) {
  const resolvedInitialState = initialState ?? {
    ...INITIAL_INVENTORY_FORM_STATE,
    values: {
      ...INITIAL_INVENTORY_FORM_STATE.values,
      allowBackorder: initialAllowBackorder === true ? "true" : "false",
    },
  };

  const action = useMemo(
    () => adjustInventory.bind(null, variantId),
    [variantId],
  );
  const [state, formAction] = useActionState(action, resolvedInitialState);
  const values = state.values;

  return (
    <form action={formAction} className="space-y-6" noValidate>
      <Field
        id="operation"
        label="Operation"
        help="Choose one stock change. Reserved quantity cannot be edited here."
        error={state.fieldErrors.operation}
      >
        <select
          id="operation"
          name="operation"
          required
          defaultValue={values.operation}
          aria-describedby={describedBy(
            "operation",
            state.fieldErrors.operation,
          )}
          aria-invalid={Boolean(state.fieldErrors.operation)}
          className={inputClassName}
        >
          {INVENTORY_OPERATIONS.map((operation) => (
            <option key={operation} value={operation}>
              {INVENTORY_OPERATION_LABELS[operation]}
            </option>
          ))}
        </select>
      </Field>
      <Field
        id="quantity"
        label="Quantity"
        help="Whole numbers only. Required for add, remove, set on-hand, and reorder updates. Leave blank when updating allow-backorder."
        error={state.fieldErrors.quantity}
      >
        <input
          id="quantity"
          name="quantity"
          type="text"
          inputMode="numeric"
          defaultValue={values.quantity}
          aria-describedby={describedBy("quantity", state.fieldErrors.quantity)}
          aria-invalid={Boolean(state.fieldErrors.quantity)}
          className={inputClassName}
        />
      </Field>
      <Field
        id="allow_backorder"
        label="Allow backorder"
        help="Used only when the operation is Update allow backorder."
        error={state.fieldErrors.allowBackorder}
      >
        <select
          id="allow_backorder"
          name="allow_backorder"
          defaultValue={values.allowBackorder}
          aria-describedby={describedBy(
            "allow_backorder",
            state.fieldErrors.allowBackorder,
          )}
          aria-invalid={Boolean(state.fieldErrors.allowBackorder)}
          className={inputClassName}
        >
          <option value="false">No</option>
          <option value="true">Yes</option>
        </select>
      </Field>
      <Field
        id="reason"
        label="Reason"
        help="Required. Choose a normalized stock-adjustment reason."
        error={state.fieldErrors.reason}
      >
        <select
          id="reason"
          name="reason"
          required
          defaultValue={values.reason}
          aria-describedby={describedBy("reason", state.fieldErrors.reason)}
          aria-invalid={Boolean(state.fieldErrors.reason)}
          className={inputClassName}
        >
          <option value="">Select a reason</option>
          {INVENTORY_REASONS.map((reason) => (
            <option key={reason} value={reason}>
              {INVENTORY_REASON_LABELS[reason]}
            </option>
          ))}
        </select>
      </Field>
      <Field
        id="note"
        label="Note"
        help="Optional. At most 500 characters."
        error={state.fieldErrors.note}
      >
        <textarea
          id="note"
          name="note"
          rows={3}
          maxLength={INVENTORY_NOTE_MAX_LENGTH}
          defaultValue={values.note}
          aria-describedby={describedBy("note", state.fieldErrors.note)}
          aria-invalid={Boolean(state.fieldErrors.note)}
          className={inputClassName}
        />
      </Field>
      <p
        aria-live="polite"
        role={state.status === "error" ? "alert" : "status"}
        className={`min-h-6 text-sm ${
          state.status === "error" ? "text-rose-300" : "text-slate-300"
        }`}
      >
        {state.message}
      </p>
      <SubmitButton />
    </form>
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
      <label htmlFor={id} className="text-sm font-medium text-slate-100">
        {label}
      </label>
      {children}
      <p id={`${id}-help`} className="text-xs text-slate-400">
        {help}
      </p>
      {error ? (
        <p id={`${id}-error`} className="text-sm text-rose-300" role="alert">
          {error}
        </p>
      ) : null}
    </div>
  );
}

function describedBy(id: string, error?: string): string {
  return error ? `${id}-help ${id}-error` : `${id}-help`;
}

function SubmitButton() {
  const { pending } = useFormStatus();
  return (
    <button
      type="submit"
      disabled={pending}
      aria-disabled={pending}
      className="inline-flex items-center justify-center rounded-full bg-emerald-300 px-5 py-3 text-sm font-semibold text-slate-950 transition hover:bg-emerald-200 disabled:cursor-not-allowed disabled:opacity-70"
    >
      {pending ? "Saving..." : "Save adjustment"}
    </button>
  );
}

const inputClassName =
  "w-full rounded-2xl border border-white/10 bg-slate-950/70 px-4 py-3 text-base text-white outline-none transition focus:border-emerald-300 focus:ring-2 focus:ring-emerald-300/30";
