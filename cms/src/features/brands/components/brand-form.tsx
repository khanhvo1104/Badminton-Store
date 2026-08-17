"use client";

import {
  Children,
  cloneElement,
  isValidElement,
  useActionState,
  type ReactElement,
  type ReactNode,
} from "react";
import { useFormStatus } from "react-dom";

import { createBrand } from "@/features/brands/actions/create-brand";
import { updateBrand } from "@/features/brands/actions/update-brand";
import { INITIAL_BRAND_FORM_STATE } from "@/features/brands/brand-form-state";
import type { BrandFormState, BrandFormValues } from "@/features/brands/types";

type BrandFormProps = {
  mode: "create" | "edit";
  brandId?: string;
  initialState?: BrandFormState;
  initialValues?: BrandFormValues;
  currentLogoUrl?: string | null;
};

export function BrandForm({
  mode,
  brandId,
  initialState,
  initialValues,
  currentLogoUrl,
}: BrandFormProps) {
  const resolvedInitialState =
    initialState ??
    (initialValues
      ? { ...INITIAL_BRAND_FORM_STATE, values: initialValues }
      : INITIAL_BRAND_FORM_STATE);

  const action = mode === "create" ? createBrand : updateBrand;
  const [state, formAction] = useActionState(action, resolvedInitialState);
  const values = state.values;

  return (
    <form action={formAction} className="space-y-6" noValidate>
      {mode === "edit" && brandId ? (
        <input type="hidden" name="id" value={brandId} />
      ) : null}
      <Field
        id="name"
        label="Name"
        help="Required. Up to 120 characters."
        error={state.fieldErrors.name}
      >
        <input
          id="name"
          name="name"
          type="text"
          required
          defaultValue={values.name}
          className={inputClassName}
        />
      </Field>
      <Field
        id="slug"
        label="Slug"
        help="Lowercase letters, numbers, and hyphens. Must be unique."
        error={state.fieldErrors.slug}
      >
        <input
          id="slug"
          name="slug"
          type="text"
          defaultValue={values.slug}
          className={inputClassName}
        />
      </Field>
      <Field
        id="description"
        label="Description"
        help="Optional. Up to 2000 characters."
        error={state.fieldErrors.description}
      >
        <textarea
          id="description"
          name="description"
          rows={4}
          defaultValue={values.description}
          className={inputClassName}
        />
      </Field>
      <Field
        id="website_url"
        label="Website URL"
        help="Optional. Absolute HTTPS URL only."
        error={state.fieldErrors.websiteUrl}
      >
        <input
          id="website_url"
          name="website_url"
          type="url"
          defaultValue={values.websiteUrl}
          className={inputClassName}
        />
      </Field>
      <Field
        id="country_of_origin"
        label="Country of origin"
        help="Optional. Up to 80 characters."
        error={state.fieldErrors.countryOfOrigin}
      >
        <input
          id="country_of_origin"
          name="country_of_origin"
          type="text"
          defaultValue={values.countryOfOrigin}
          className={inputClassName}
        />
      </Field>
      <Field
        id="sort_order"
        label="Sort order"
        help="Lower numbers appear first."
        error={state.fieldErrors.sortOrder}
      >
        <input
          id="sort_order"
          name="sort_order"
          type="number"
          required
          defaultValue={values.sortOrder}
          className={inputClassName}
        />
      </Field>
      <fieldset className="space-y-3">
        <legend className="text-sm font-medium text-slate-100">
          Visibility
        </legend>
        <label className="flex items-center gap-3 text-sm text-slate-200">
          <input
            type="checkbox"
            name="is_active"
            value="true"
            defaultChecked={values.isActive}
            className="size-4 rounded border-white/20 bg-slate-950 text-emerald-300"
          />
          Active and visible to public catalog readers
        </label>
      </fieldset>
      <Field
        id="logo"
        label="Brand logo"
        help="Optional. JPEG, PNG, WebP, or SVG up to 2 MiB. SVG is shown as an image, never inline."
        error={state.fieldErrors.logo}
      >
        {currentLogoUrl ? (
          // eslint-disable-next-line @next/next/no-img-element
          <img
            src={currentLogoUrl}
            alt="Current brand logo"
            width={96}
            height={96}
            className="mb-3 h-24 w-24 rounded-2xl object-contain"
          />
        ) : null}
        <input
          id="logo"
          name="logo"
          type="file"
          accept="image/jpeg,image/png,image/webp,image/svg+xml"
          className="block w-full text-sm text-slate-300 file:mr-4 file:rounded-full file:border-0 file:bg-emerald-300 file:px-4 file:py-2 file:text-sm file:font-semibold file:text-slate-950"
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
        label={mode === "create" ? "Create brand" : "Save changes"}
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
