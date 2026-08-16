"use client";

import { useActionState, type ReactNode } from "react";
import { useFormStatus } from "react-dom";

import { createCategory } from "@/features/categories/actions/create-category";
import { updateCategory } from "@/features/categories/actions/update-category";
import { INITIAL_CATEGORY_FORM_STATE } from "@/features/categories/category-form-state";
import type {
  CategoryFormState,
  CategoryFormValues,
  CategoryParentOption,
} from "@/features/categories/types";

type CategoryFormProps = {
  mode: "create" | "edit";
  categoryId?: string;
  initialState?: CategoryFormState;
  initialValues?: CategoryFormValues;
  parentOptions: CategoryParentOption[];
  currentImageUrl?: string | null;
};

export function CategoryForm({
  mode,
  categoryId,
  initialState,
  initialValues,
  parentOptions,
  currentImageUrl,
}: CategoryFormProps) {
  const resolvedInitialState =
    initialState ??
    (initialValues
      ? { ...INITIAL_CATEGORY_FORM_STATE, values: initialValues }
      : INITIAL_CATEGORY_FORM_STATE);

  const action = mode === "create" ? createCategory : updateCategory;
  const [state, formAction] = useActionState(action, resolvedInitialState);
  const values = state.values;
  const parents = parentOptions.filter((option) => option.id !== categoryId);

  return (
    <form
      action={formAction}
      className="space-y-6"
      noValidate
      encType="multipart/form-data"
    >
      {mode === "edit" && categoryId ? (
        <input type="hidden" name="id" value={categoryId} />
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
        help="Lowercase letters, numbers, and hyphens."
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
        id="parent_id"
        label="Parent category"
        help="Optional. Cannot parent itself or a descendant."
        error={state.fieldErrors.parentId}
      >
        <select
          id="parent_id"
          name="parent_id"
          defaultValue={values.parentId}
          className={inputClassName}
        >
          <option value="">No parent</option>
          {parents.map((option) => (
            <option key={option.id} value={option.id}>
              {option.name}
              {option.isActive ? "" : " (inactive)"}
            </option>
          ))}
        </select>
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
        id="image"
        label="Category image"
        help="Optional. JPEG, PNG, WebP, or SVG up to 2 MiB."
        error={state.fieldErrors.image}
      >
        {currentImageUrl ? (
          // eslint-disable-next-line @next/next/no-img-element
          <img
            src={currentImageUrl}
            alt="Current category"
            width={96}
            height={96}
            className="mb-3 h-24 w-24 rounded-2xl object-cover"
          />
        ) : null}
        <input
          id="image"
          name="image"
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
        label={mode === "create" ? "Create category" : "Save changes"}
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
  return (
    <div className="space-y-2">
      <label htmlFor={id} className="text-sm font-medium text-slate-100">
        {label}
      </label>
      {children}
      <p className="text-xs text-slate-400">{help}</p>
      {error ? (
        <p className="text-sm text-rose-300" role="alert">
          {error}
        </p>
      ) : null}
    </div>
  );
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
