"use client";

import {
  Children,
  cloneElement,
  isValidElement,
  useActionState,
  useMemo,
  type ReactElement,
  type ReactNode,
} from "react";
import { useFormStatus } from "react-dom";

import { createVariant } from "@/features/variants/actions/create-variant";
import { updateVariant } from "@/features/variants/actions/update-variant";
import { INITIAL_VARIANT_FORM_STATE } from "@/features/variants/variant-form-state";
import type {
  VariantFormState,
  VariantFormValues,
} from "@/features/variants/types";

type VariantFormProps = {
  mode: "create" | "edit";
  productId: string;
  variantId?: string;
  isFirstVariant?: boolean;
  currentIsDefault?: boolean;
  initialState?: VariantFormState;
  initialValues?: VariantFormValues;
};

export function VariantForm({
  mode,
  productId,
  variantId,
  isFirstVariant = false,
  currentIsDefault = false,
  initialState,
  initialValues,
}: VariantFormProps) {
  const resolvedInitialState =
    initialState ??
    (initialValues
      ? { ...INITIAL_VARIANT_FORM_STATE, values: initialValues }
      : {
          ...INITIAL_VARIANT_FORM_STATE,
          values: {
            ...INITIAL_VARIANT_FORM_STATE.values,
            isDefault: isFirstVariant ? "true" : "false",
          },
        });

  const action = useMemo(() => {
    if (mode === "create") {
      return createVariant.bind(null, productId);
    }
    return updateVariant.bind(null, productId, variantId ?? "");
  }, [mode, productId, variantId]);

  const [state, formAction] = useActionState(action, resolvedInitialState);
  const values = state.values;

  return (
    <form action={formAction} className="space-y-6" noValidate>
      <Field
        id="sku"
        label="SKU"
        help="Required. Trimmed with internal spaces collapsed; case is preserved. Max 80 characters. Must be unique."
        error={state.fieldErrors.sku}
      >
        <input
          id="sku"
          name="sku"
          type="text"
          required
          defaultValue={values.sku}
          className={inputClassName}
        />
      </Field>
      <Field
        id="name"
        label="Name"
        help="Optional display name. Max 200 characters."
        error={state.fieldErrors.name}
      >
        <input
          id="name"
          name="name"
          type="text"
          defaultValue={values.name}
          className={inputClassName}
        />
      </Field>
      <Field
        id="color_name"
        label="Color name"
        help="Optional. Blank becomes empty."
        error={state.fieldErrors.colorName}
      >
        <input
          id="color_name"
          name="color_name"
          type="text"
          defaultValue={values.colorName}
          className={inputClassName}
        />
      </Field>
      <Field
        id="color_hex"
        label="Color hex"
        help="Optional #RRGGBB value, for example #C62828."
        error={state.fieldErrors.colorHex}
      >
        <input
          id="color_hex"
          name="color_hex"
          type="text"
          defaultValue={values.colorHex}
          className={inputClassName}
        />
      </Field>
      <Field
        id="racket_weight_class"
        label="Racket weight class"
        help="Optional sports attribute. Blank becomes empty. Not category-constrained."
        error={state.fieldErrors.racketWeightClass}
      >
        <input
          id="racket_weight_class"
          name="racket_weight_class"
          type="text"
          defaultValue={values.racketWeightClass}
          className={inputClassName}
        />
      </Field>
      <Field
        id="grip_size"
        label="Grip size"
        help="Optional. Blank becomes empty."
        error={state.fieldErrors.gripSize}
      >
        <input
          id="grip_size"
          name="grip_size"
          type="text"
          defaultValue={values.gripSize}
          className={inputClassName}
        />
      </Field>
      <Field
        id="shoe_size"
        label="Shoe size"
        help="Optional. Blank becomes empty."
        error={state.fieldErrors.shoeSize}
      >
        <input
          id="shoe_size"
          name="shoe_size"
          type="text"
          defaultValue={values.shoeSize}
          className={inputClassName}
        />
      </Field>
      <Field
        id="clothing_size"
        label="Clothing size"
        help="Optional. Blank becomes empty."
        error={state.fieldErrors.clothingSize}
      >
        <input
          id="clothing_size"
          name="clothing_size"
          type="text"
          defaultValue={values.clothingSize}
          className={inputClassName}
        />
      </Field>
      <Field
        id="unit"
        label="Unit"
        help="Required. 1 to 40 characters."
        error={state.fieldErrors.unit}
      >
        <input
          id="unit"
          name="unit"
          type="text"
          required
          defaultValue={values.unit}
          className={inputClassName}
        />
      </Field>
      <Field
        id="price"
        label="Selling price"
        help="Required nonnegative amount with at most two decimal places."
        error={state.fieldErrors.price}
      >
        <input
          id="price"
          name="price"
          type="text"
          inputMode="decimal"
          required
          defaultValue={values.price}
          className={inputClassName}
        />
      </Field>
      <Field
        id="compare_at_price"
        label="Compare-at price"
        help="Optional. Must be greater than or equal to the selling price when set."
        error={state.fieldErrors.compareAtPrice}
      >
        <input
          id="compare_at_price"
          name="compare_at_price"
          type="text"
          inputMode="decimal"
          defaultValue={values.compareAtPrice}
          className={inputClassName}
        />
      </Field>
      <Field
        id="cost_price"
        label="Protected cost"
        help="Staff-only cost. Empty clears the recorded cost. Zero is stored as zero, not as empty."
        error={state.fieldErrors.costPrice}
      >
        <input
          id="cost_price"
          name="cost_price"
          type="text"
          inputMode="decimal"
          defaultValue={values.costPrice}
          className={inputClassName}
        />
      </Field>
      <Field
        id="barcode"
        label="Barcode"
        help={
          mode === "edit"
            ? "Leave blank to keep the existing barcode. The editor cannot read the current barcode. Enter a new value to replace it, or check clear barcode."
            : "Optional. Create can set a barcode; it cannot be shown later in this editor."
        }
        error={state.fieldErrors.barcode}
      >
        <input
          id="barcode"
          name="barcode"
          type="text"
          autoComplete="off"
          defaultValue={values.barcode}
          className={inputClassName}
        />
      </Field>
      {mode === "edit" ? (
        <label className="flex items-center gap-3 text-sm text-slate-200">
          <input
            type="checkbox"
            name="barcode_clear"
            value="true"
            defaultChecked={values.barcodeClear}
            className="size-4 rounded border-white/20 bg-slate-950 text-emerald-300"
          />
          Clear barcode
        </label>
      ) : null}
      <Field
        id="attributes"
        label="Attributes"
        help="Optional JSON object with bounded nested keys and scalar values. Arrays and prototype keys are rejected."
        error={state.fieldErrors.attributes}
      >
        <textarea
          id="attributes"
          name="attributes"
          rows={8}
          defaultValue={values.attributes}
          className={`${inputClassName} font-mono text-sm`}
        />
      </Field>
      <Field
        id="is_default"
        label="Default variant"
        help={
          isFirstVariant
            ? "The first variant for a product always becomes the default."
            : currentIsDefault
              ? "This variant is the current default. Choose another variant as default instead of turning this one off."
              : "Setting this as default unsets the previous default in the same save."
        }
        error={state.fieldErrors.isDefault}
      >
        <select
          id="is_default"
          name="is_default"
          required
          defaultValue={values.isDefault}
          className={inputClassName}
        >
          <option value="true">Yes</option>
          <option value="false">No</option>
        </select>
      </Field>
      <Field
        id="is_active"
        label="Active"
        help="Inactive variants stay on the product but are hidden from the public catalog."
        error={state.fieldErrors.isActive}
      >
        <select
          id="is_active"
          name="is_active"
          required
          defaultValue={values.isActive}
          className={inputClassName}
        >
          <option value="true">Yes</option>
          <option value="false">No</option>
        </select>
      </Field>
      <Field
        id="sort_order"
        label="Sort order"
        help="Integer between -1,000,000 and 1,000,000."
        error={state.fieldErrors.sortOrder}
      >
        <input
          id="sort_order"
          name="sort_order"
          type="text"
          inputMode="numeric"
          required
          defaultValue={values.sortOrder}
          className={inputClassName}
        />
      </Field>
      <p
        aria-live="polite"
        role={state.status === "error" ? "alert" : "status"}
        className={`min-h-6 text-sm ${
          state.status === "error"
            ? "text-rose-300"
            : state.status === "success"
              ? "text-emerald-200"
              : "text-slate-300"
        }`}
      >
        {state.message}
      </p>
      <SubmitButton
        label={mode === "create" ? "Create variant" : "Save changes"}
      />
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
  const helpId = `${id}-help`;
  const errorId = `${id}-error`;
  const describedBy = error ? `${helpId} ${errorId}` : helpId;

  return (
    <div className="space-y-2">
      <label htmlFor={id} className="text-sm font-medium text-slate-100">
        {label}
      </label>
      {associateFieldControl(children, id, describedBy, Boolean(error))}
      <p id={helpId} className="text-xs text-slate-400">
        {help}
      </p>
      {error ? (
        <p id={errorId} className="text-sm text-rose-300" role="alert">
          {error}
        </p>
      ) : null}
    </div>
  );
}

type DescribableProps = {
  id?: string;
  children?: ReactNode;
  "aria-describedby"?: string;
  "aria-invalid"?: boolean;
};

function associateFieldControl(
  children: ReactNode,
  controlId: string,
  describedBy: string,
  invalid: boolean,
): ReactNode {
  return Children.map(children, (child) => {
    if (!isValidElement(child)) {
      return child;
    }

    const element = child as ReactElement<DescribableProps>;
    if (element.props.id === controlId) {
      return cloneElement(element, {
        "aria-describedby": describedBy,
        ...(invalid ? { "aria-invalid": true } : {}),
      });
    }

    if (element.props.children) {
      return cloneElement(element, {
        children: associateFieldControl(
          element.props.children,
          controlId,
          describedBy,
          invalid,
        ),
      });
    }

    return child;
  });
}

function SubmitButton({ label }: { label: string }) {
  const { pending } = useFormStatus();
  return (
    <button
      type="submit"
      disabled={pending}
      aria-disabled={pending}
      className="inline-flex items-center justify-center rounded-full bg-emerald-300 px-5 py-3 text-sm font-semibold text-slate-950 transition hover:bg-emerald-200 disabled:cursor-not-allowed disabled:opacity-70"
    >
      {pending ? "Saving..." : label}
    </button>
  );
}

const inputClassName =
  "w-full rounded-2xl border border-white/10 bg-slate-950/70 px-4 py-3 text-base text-white outline-none transition focus:border-emerald-300 focus:ring-2 focus:ring-emerald-300/30";
