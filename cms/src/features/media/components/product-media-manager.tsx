"use client";

import { useActionState, useMemo, type ReactNode } from "react";
import { useFormStatus } from "react-dom";

import { EmptyState } from "@/components/ui/empty-state";
import { StatusBadge } from "@/components/ui/status-badge";
import { deleteProductImage } from "@/features/media/actions/delete-product-image";
import { reorderProductImages } from "@/features/media/actions/reorder-product-images";
import { replaceProductImage } from "@/features/media/actions/replace-product-image";
import { setProductImagePrimary } from "@/features/media/actions/set-product-image-primary";
import { updateProductImage } from "@/features/media/actions/update-product-image";
import { uploadProductImage } from "@/features/media/actions/upload-product-image";
import {
  INITIAL_DELETE_MEDIA_FORM_STATE,
  INITIAL_PRIMARY_MEDIA_FORM_STATE,
  INITIAL_REORDER_MEDIA_FORM_STATE,
  INITIAL_REPLACE_MEDIA_FORM_STATE,
  INITIAL_UPDATE_MEDIA_FORM_STATE,
  INITIAL_UPLOAD_MEDIA_FORM_STATE,
  updateFormValuesFromImage,
} from "@/features/media/form-state";
import type {
  ProductMediaImage,
  ProductMediaVariantOption,
} from "@/features/media/types";

type ProductMediaManagerProps = {
  productId: string;
  images: ProductMediaImage[];
  variants: ProductMediaVariantOption[];
};

export function ProductMediaManager({
  productId,
  images,
  variants,
}: ProductMediaManagerProps) {
  return (
    <div className="space-y-8">
      <UploadForm productId={productId} variants={variants} />
      {images.length === 0 ? (
        <EmptyState
          title="No images yet"
          description="Upload a JPEG, PNG, WebP, or GIF image. The first image in each product or variant scope becomes primary."
        />
      ) : (
        <ul className="grid gap-6">
          {images.map((image, index) => (
            <li key={image.id}>
              <ImageCard
                productId={productId}
                image={image}
                variants={variants}
                canMoveUp={index > 0}
                canMoveDown={index < images.length - 1}
                orderedIds={images.map((item) => item.id)}
              />
            </li>
          ))}
        </ul>
      )}
    </div>
  );
}

function UploadForm({
  productId,
  variants,
}: {
  productId: string;
  variants: ProductMediaVariantOption[];
}) {
  const action = useMemo(
    () => uploadProductImage.bind(null, productId),
    [productId],
  );
  const [state, formAction] = useActionState(
    action,
    INITIAL_UPLOAD_MEDIA_FORM_STATE,
  );

  return (
    <section className="rounded-3xl border border-white/10 bg-slate-900/60 p-6">
      <h2 className="text-lg font-semibold text-white">Upload image</h2>
      <p className="mt-2 text-sm leading-7 text-slate-300">
        JPEG, PNG, WebP, or GIF up to 5 MiB. At most 20 images per product.
        Never upload SVG.
      </p>
      <form action={formAction} className="mt-4 space-y-4" noValidate>
        <Field
          id="image"
          label="Image file"
          help="Required. Raster images only."
          error={state.fieldErrors.image}
        >
          <input
            id="image"
            name="image"
            type="file"
            accept="image/jpeg,image/png,image/webp,image/gif"
            className={inputClassName}
          />
        </Field>
        <Field
          id="alt_text"
          label="Alt text"
          help="Optional. Up to 200 characters."
          error={state.fieldErrors.altText}
        >
          <input
            id="alt_text"
            name="alt_text"
            type="text"
            defaultValue={state.values.altText}
            className={inputClassName}
          />
        </Field>
        <Field
          id="variant_id"
          label="Variant"
          help="Optional. Must belong to this product."
          error={state.fieldErrors.variantId}
        >
          <select
            id="variant_id"
            name="variant_id"
            defaultValue={state.values.variantId}
            className={inputClassName}
          >
            <option value="">Product gallery</option>
            {variants.map((variant) => (
              <option key={variant.id} value={variant.id}>
                {variant.label}
              </option>
            ))}
          </select>
        </Field>
        <label className="flex items-start gap-3 text-sm text-slate-200">
          <input
            name="set_primary"
            type="checkbox"
            value="yes"
            defaultChecked={state.values.setPrimary}
            className="mt-1 h-4 w-4 rounded border-white/20 bg-slate-950 text-emerald-300"
          />
          Set as primary for this product or variant scope
        </label>
        <FormMessage status={state.status} message={state.message} />
        <SubmitButton label="Upload image" pendingLabel="Uploading..." />
      </form>
    </section>
  );
}

function ImageCard({
  productId,
  image,
  variants,
  canMoveUp,
  canMoveDown,
  orderedIds,
}: {
  productId: string;
  image: ProductMediaImage;
  variants: ProductMediaVariantOption[];
  canMoveUp: boolean;
  canMoveDown: boolean;
  orderedIds: string[];
}) {
  const updateAction = useMemo(
    () => updateProductImage.bind(null, productId, image.id),
    [productId, image.id],
  );
  const replaceAction = useMemo(
    () => replaceProductImage.bind(null, productId, image.id),
    [productId, image.id],
  );
  const primaryAction = useMemo(
    () => setProductImagePrimary.bind(null, productId, image.id),
    [productId, image.id],
  );
  const deleteAction = useMemo(
    () => deleteProductImage.bind(null, productId, image.id),
    [productId, image.id],
  );
  const reorderAction = useMemo(
    () => reorderProductImages.bind(null, productId),
    [productId],
  );

  const [updateState, updateFormAction] = useActionState(updateAction, {
    ...INITIAL_UPDATE_MEDIA_FORM_STATE,
    values: updateFormValuesFromImage(image),
  });
  const [replaceState, replaceFormAction] = useActionState(
    replaceAction,
    INITIAL_REPLACE_MEDIA_FORM_STATE,
  );
  const [primaryState, primaryFormAction] = useActionState(
    primaryAction,
    INITIAL_PRIMARY_MEDIA_FORM_STATE,
  );
  const [deleteState, deleteFormAction] = useActionState(
    deleteAction,
    INITIAL_DELETE_MEDIA_FORM_STATE,
  );
  const [reorderState, reorderFormAction] = useActionState(
    reorderAction,
    INITIAL_REORDER_MEDIA_FORM_STATE,
  );

  const movedUp = canMoveUp ? swapIds(orderedIds, image.id, -1) : orderedIds;
  const movedDown = canMoveDown ? swapIds(orderedIds, image.id, 1) : orderedIds;

  return (
    <article className="space-y-6 rounded-3xl border border-white/10 bg-slate-900/60 p-6">
      <div className="flex flex-col gap-4 sm:flex-row">
        <div className="overflow-hidden rounded-2xl border border-white/10 bg-slate-950 sm:w-48">
          {image.previewUrl ? (
            // Safe public raster preview from a stored path. SVG is rejected.
            // eslint-disable-next-line @next/next/no-img-element
            <img
              src={image.previewUrl}
              alt={image.altText ?? ""}
              className="aspect-square w-full object-cover"
            />
          ) : (
            <div className="flex aspect-square items-center justify-center p-4 text-sm text-slate-400">
              Preview unavailable
            </div>
          )}
        </div>
        <div className="space-y-2 text-sm text-slate-300">
          <StatusBadge tone={image.isPrimary ? "success" : "neutral"}>
            {image.primaryLabel}
          </StatusBadge>
          <p>{image.scopeLabel}</p>
          <p>Sort {image.sortOrder}</p>
        </div>
      </div>

      <form action={updateFormAction} className="space-y-4" noValidate>
        <Field
          id={`alt-${image.id}`}
          label="Alt text"
          help="Optional. Up to 200 characters."
          error={updateState.fieldErrors.altText}
        >
          <input
            id={`alt-${image.id}`}
            name="alt_text"
            type="text"
            defaultValue={updateState.values.altText}
            className={inputClassName}
          />
        </Field>
        <Field
          id={`variant-${image.id}`}
          label="Variant"
          help="Reassigning a primary image promotes the next remaining image in the old scope."
          error={updateState.fieldErrors.variantId}
        >
          <select
            id={`variant-${image.id}`}
            name="variant_id"
            defaultValue={updateState.values.variantId}
            className={inputClassName}
          >
            <option value="">Product gallery</option>
            {variants.map((variant) => (
              <option key={variant.id} value={variant.id}>
                {variant.label}
              </option>
            ))}
          </select>
        </Field>
        <Field
          id={`sort-${image.id}`}
          label="Sort order"
          help="Whole number used as a fallback when the ordered list is not submitted."
          error={updateState.fieldErrors.sortOrder}
        >
          <input
            id={`sort-${image.id}`}
            name="sort_order"
            type="text"
            inputMode="numeric"
            defaultValue={updateState.values.sortOrder}
            className={inputClassName}
          />
        </Field>
        <FormMessage
          status={updateState.status}
          message={updateState.message}
        />
        <SubmitButton label="Save details" pendingLabel="Saving..." />
      </form>

      <div className="flex flex-wrap gap-3">
        {canMoveUp ? (
          <form action={reorderFormAction}>
            {movedUp.map((id) => (
              <input key={id} type="hidden" name="image_ids" value={id} />
            ))}
            <SubmitButton label="Move up" pendingLabel="Reordering..." />
          </form>
        ) : null}
        {canMoveDown ? (
          <form action={reorderFormAction}>
            {movedDown.map((id) => (
              <input key={id} type="hidden" name="image_ids" value={id} />
            ))}
            <SubmitButton label="Move down" pendingLabel="Reordering..." />
          </form>
        ) : null}
        {!image.isPrimary ? (
          <form action={primaryFormAction}>
            <SubmitButton label="Set primary" pendingLabel="Updating..." />
          </form>
        ) : null}
      </div>
      <FormMessage
        status={primaryState.status}
        message={primaryState.message}
      />
      <FormMessage
        status={reorderState.status}
        message={reorderState.message}
      />

      <form action={replaceFormAction} className="space-y-4">
        <Field
          id={`replace-${image.id}`}
          label="Replace file"
          help="Uploads a new unique object, then updates the database path, then removes the old file."
          error={replaceState.fieldErrors.image}
        >
          <input
            id={`replace-${image.id}`}
            name="image"
            type="file"
            accept="image/jpeg,image/png,image/webp,image/gif"
            className={inputClassName}
          />
        </Field>
        <FormMessage
          status={replaceState.status}
          message={replaceState.message}
        />
        <SubmitButton label="Replace image" pendingLabel="Replacing..." />
      </form>

      <form action={deleteFormAction} className="space-y-4">
        <label className="flex items-start gap-3 text-sm text-slate-200">
          <input
            name="confirmed"
            type="checkbox"
            value="yes"
            required
            className="mt-1 h-4 w-4 rounded border-white/20 bg-slate-950 text-emerald-300"
          />
          I confirm I want to delete this image
          {image.isPrimary
            ? ". The next remaining image in this scope will become primary."
            : "."}
        </label>
        <FormMessage
          status={deleteState.status}
          message={deleteState.message}
        />
        <SubmitButton label="Delete image" pendingLabel="Deleting..." />
      </form>
    </article>
  );
}

function swapIds(ids: string[], imageId: string, delta: number): string[] {
  const next = [...ids];
  const index = next.indexOf(imageId);
  const target = index + delta;
  if (index < 0 || target < 0 || target >= next.length) {
    return next;
  }
  const current = next[index];
  const other = next[target];
  if (!current || !other) {
    return next;
  }
  next[index] = other;
  next[target] = current;
  return next;
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
  return (
    <div className="space-y-2">
      <label htmlFor={id} className="text-sm font-medium text-slate-100">
        {label}
      </label>
      {children}
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

function FormMessage({
  status,
  message,
}: {
  status: "idle" | "error" | "success";
  message: string;
}) {
  if (!message) {
    return null;
  }
  return (
    <p
      role={status === "error" ? "alert" : "status"}
      aria-live="polite"
      className={
        status === "success"
          ? "text-sm text-emerald-200"
          : "text-sm text-rose-300"
      }
    >
      {message}
    </p>
  );
}

function SubmitButton({
  label,
  pendingLabel,
}: {
  label: string;
  pendingLabel: string;
}) {
  const { pending } = useFormStatus();
  return (
    <button
      type="submit"
      disabled={pending}
      aria-disabled={pending}
      className="inline-flex items-center justify-center rounded-full bg-emerald-300 px-5 py-3 text-sm font-semibold text-slate-950 transition hover:bg-emerald-200 disabled:cursor-not-allowed disabled:opacity-70"
    >
      {pending ? pendingLabel : label}
    </button>
  );
}

const inputClassName =
  "w-full rounded-2xl border border-white/10 bg-slate-950/70 px-4 py-3 text-base text-white outline-none transition focus:border-emerald-300 focus:ring-2 focus:ring-emerald-300/30";
