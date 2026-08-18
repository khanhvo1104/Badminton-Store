"use client";

import {
  Children,
  cloneElement,
  isValidElement,
  useActionState,
  useMemo,
  useRef,
  type ChangeEvent,
  type ReactElement,
  type ReactNode,
} from "react";
import { useFormStatus } from "react-dom";

import { createProduct } from "@/features/products/actions/create-product";
import { updateProduct } from "@/features/products/actions/update-product";
import {
  PRODUCT_STATUSES,
  PRODUCT_STATUS_LABELS,
} from "@/features/products/constants";
import { suggestProductSlugFromName } from "@/features/products/form-validation";
import { INITIAL_PRODUCT_FORM_STATE } from "@/features/products/product-form-state";
import type {
  ProductFormReferenceOption,
  ProductFormState,
  ProductFormValues,
} from "@/features/products/types";

type ProductFormProps = {
  mode: "create" | "edit";
  productId?: string;
  initialState?: ProductFormState;
  initialValues?: ProductFormValues;
  categories: ProductFormReferenceOption[];
  brands: ProductFormReferenceOption[];
};

export function ProductForm({
  mode,
  productId,
  initialState,
  initialValues,
  categories,
  brands,
}: ProductFormProps) {
  const resolvedInitialState =
    initialState ??
    (initialValues
      ? { ...INITIAL_PRODUCT_FORM_STATE, values: initialValues }
      : INITIAL_PRODUCT_FORM_STATE);

  const boundUpdateProduct = useMemo(
    () =>
      productId
        ? (updateProduct.bind(null, productId) as typeof createProduct)
        : createProduct,
    [productId],
  );
  const action = mode === "create" ? createProduct : boundUpdateProduct;
  const [state, formAction] = useActionState(action, resolvedInitialState);
  const values = state.values;
  const slugInputRef = useRef<HTMLInputElement>(null);
  const slugManualRef = useRef(values.slugManual);
  const slugManualInputRef = useRef<HTMLInputElement>(null);

  function handleNameChange(event: ChangeEvent<HTMLInputElement>) {
    if (!slugManualRef.current && slugInputRef.current) {
      slugInputRef.current.value = suggestProductSlugFromName(
        event.target.value,
      );
    }
  }

  function handleSlugChange() {
    slugManualRef.current = true;
    if (slugManualInputRef.current) {
      slugManualInputRef.current.value = "true";
    }
  }

  return (
    <form action={formAction} className="space-y-6" noValidate>
      <input
        ref={slugManualInputRef}
        type="hidden"
        name="slug_manual"
        defaultValue={values.slugManual ? "true" : "false"}
      />
      <Field
        id="category_id"
        label="Category"
        help="Required. Only active categories can be chosen for new products."
        error={state.fieldErrors.categoryId}
      >
        <select
          id="category_id"
          name="category_id"
          required
          defaultValue={values.categoryId}
          className={inputClassName}
        >
          <option value="">Select a category</option>
          {categories.map((option) => (
            <option key={option.id} value={option.id}>
              {option.isActive ? option.name : `${option.name} (inactive)`}
            </option>
          ))}
        </select>
      </Field>
      <Field
        id="brand_id"
        label="Brand"
        help="Optional. Only active brands can be chosen unless you keep the current inactive brand."
        error={state.fieldErrors.brandId}
      >
        <select
          id="brand_id"
          name="brand_id"
          defaultValue={values.brandId}
          className={inputClassName}
        >
          <option value="">No brand</option>
          {brands.map((option) => (
            <option key={option.id} value={option.id}>
              {option.isActive ? option.name : `${option.name} (inactive)`}
            </option>
          ))}
        </select>
      </Field>
      <Field
        id="name"
        label="Name"
        help={`Required. Up to 200 characters.`}
        error={state.fieldErrors.name}
      >
        <input
          id="name"
          name="name"
          type="text"
          required
          defaultValue={values.name}
          onChange={handleNameChange}
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
          key={`slug-${values.slug}-${values.slugManual}`}
          ref={slugInputRef}
          name="slug"
          type="text"
          defaultValue={values.slug}
          onChange={handleSlugChange}
          className={inputClassName}
        />
      </Field>
      <Field
        id="short_description"
        label="Short description"
        help="Optional. Up to 500 characters."
        error={state.fieldErrors.shortDescription}
      >
        <textarea
          id="short_description"
          name="short_description"
          rows={3}
          defaultValue={values.shortDescription}
          className={inputClassName}
        />
      </Field>
      <Field
        id="description"
        label="Description"
        help="Optional plain text. Up to 10,000 characters. Never rendered as HTML."
        error={state.fieldErrors.description}
      >
        <textarea
          id="description"
          name="description"
          rows={6}
          defaultValue={values.description}
          className={inputClassName}
        />
      </Field>
      <Field
        id="specifications"
        label="Specifications"
        help="Optional JSON object with bounded nested keys and scalar values."
        error={state.fieldErrors.specifications}
      >
        <textarea
          id="specifications"
          name="specifications"
          rows={8}
          defaultValue={values.specifications}
          className={`${inputClassName} font-mono text-sm`}
        />
      </Field>
      <Field
        id="search_keywords"
        label="Search keywords"
        help="Optional. Up to 500 characters."
        error={state.fieldErrors.searchKeywords}
      >
        <input
          id="search_keywords"
          name="search_keywords"
          type="text"
          defaultValue={values.searchKeywords}
          className={inputClassName}
        />
      </Field>
      <Field
        id="status"
        label="Status"
        help="Active products require a publication time."
        error={state.fieldErrors.status}
      >
        <select
          id="status"
          name="status"
          defaultValue={values.status}
          className={inputClassName}
        >
          {PRODUCT_STATUSES.map((status) => (
            <option key={status} value={status}>
              {PRODUCT_STATUS_LABELS[status]}
            </option>
          ))}
        </select>
      </Field>
      <Field
        id="published_at"
        label="Published at"
        help="Optional for non-active statuses. Active products default to the current server time when empty."
        error={state.fieldErrors.publishedAt}
      >
        <input
          id="published_at"
          name="published_at"
          type="datetime-local"
          defaultValue={values.publishedAt}
          className={inputClassName}
        />
      </Field>
      <fieldset className="space-y-3">
        <legend className="text-sm font-medium text-slate-100">
          Merchandising
        </legend>
        <label className="flex items-center gap-3 text-sm text-slate-200">
          <input
            type="checkbox"
            name="is_featured"
            value="true"
            defaultChecked={values.isFeatured}
            className="size-4 rounded border-white/20 bg-slate-950 text-emerald-300"
          />
          Featured product
        </label>
      </fieldset>
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
        label={mode === "create" ? "Create product" : "Save changes"}
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
