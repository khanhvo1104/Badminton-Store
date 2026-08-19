import {
  parseCheckboxFlag,
  parseOptionalAltText,
  parseOptionalVariantId,
  parseSortOrder,
} from "@/features/media/validation";
import type {
  UpdateMediaFormValues,
  UploadMediaFormValues,
} from "@/features/media/types";

export const EMPTY_UPLOAD_MEDIA_FORM_VALUES: UploadMediaFormValues = {
  altText: "",
  variantId: "",
  setPrimary: false,
};

export const INITIAL_UPLOAD_MEDIA_FORM_STATE = {
  status: "idle" as const,
  message: "",
  fieldErrors: {},
  values: EMPTY_UPLOAD_MEDIA_FORM_VALUES,
};

export const INITIAL_UPDATE_MEDIA_FORM_STATE = {
  status: "idle" as const,
  message: "",
  fieldErrors: {},
  values: {
    altText: "",
    variantId: "",
    sortOrder: "0",
  } satisfies UpdateMediaFormValues,
};

export const INITIAL_REPLACE_MEDIA_FORM_STATE = {
  status: "idle" as const,
  message: "",
  fieldErrors: {},
};

export const INITIAL_DELETE_MEDIA_FORM_STATE = {
  status: "idle" as const,
  message: "",
  fieldErrors: {},
};

export const INITIAL_PRIMARY_MEDIA_FORM_STATE = {
  status: "idle" as const,
  message: "",
  fieldErrors: {},
};

export const INITIAL_REORDER_MEDIA_FORM_STATE = {
  status: "idle" as const,
  message: "",
  fieldErrors: {},
};

export function readUploadMediaFormValues(
  formData: FormData,
): UploadMediaFormValues {
  const altRaw = formData.get("alt_text");
  const variantRaw = formData.get("variant_id");
  return {
    altText: typeof altRaw === "string" ? altRaw : "",
    variantId: typeof variantRaw === "string" ? variantRaw : "",
    setPrimary: parseCheckboxFlag(formData.get("set_primary")),
  };
}

export function parseUploadMediaFormInput(formData: FormData):
  | {
      ok: true;
      values: UploadMediaFormValues;
      data: {
        altText: string | null;
        variantId: string | null;
        setPrimary: boolean;
      };
    }
  | {
      ok: false;
      values: UploadMediaFormValues;
      message: string;
      fieldErrors: { altText?: string; variantId?: string };
    } {
  const values = readUploadMediaFormValues(formData);
  const alt = parseOptionalAltText(values.altText);
  if (!alt.ok) {
    return {
      ok: false,
      values,
      message: alt.message,
      fieldErrors: { altText: alt.message },
    };
  }
  const variant = parseOptionalVariantId(values.variantId);
  if (!variant.ok) {
    return {
      ok: false,
      values,
      message: variant.message,
      fieldErrors: { variantId: variant.message },
    };
  }
  return {
    ok: true,
    values,
    data: {
      altText: alt.value,
      variantId: variant.value,
      setPrimary: values.setPrimary,
    },
  };
}

export function readUpdateMediaFormValues(
  formData: FormData,
): UpdateMediaFormValues {
  const altRaw = formData.get("alt_text");
  const variantRaw = formData.get("variant_id");
  const sortRaw = formData.get("sort_order");
  return {
    altText: typeof altRaw === "string" ? altRaw : "",
    variantId: typeof variantRaw === "string" ? variantRaw : "",
    sortOrder: typeof sortRaw === "string" ? sortRaw : "",
  };
}

export function parseUpdateMediaFormInput(formData: FormData):
  | {
      ok: true;
      values: UpdateMediaFormValues;
      data: {
        altText: string | null;
        variantId: string | null;
        sortOrder: number;
      };
    }
  | {
      ok: false;
      values: UpdateMediaFormValues;
      message: string;
      fieldErrors: {
        altText?: string;
        variantId?: string;
        sortOrder?: string;
      };
    } {
  const values = readUpdateMediaFormValues(formData);
  const alt = parseOptionalAltText(values.altText);
  if (!alt.ok) {
    return {
      ok: false,
      values,
      message: alt.message,
      fieldErrors: { altText: alt.message },
    };
  }
  const variant = parseOptionalVariantId(values.variantId);
  if (!variant.ok) {
    return {
      ok: false,
      values,
      message: variant.message,
      fieldErrors: { variantId: variant.message },
    };
  }
  const sortOrder = parseSortOrder(values.sortOrder);
  if (!sortOrder.ok) {
    return {
      ok: false,
      values,
      message: sortOrder.message,
      fieldErrors: { sortOrder: sortOrder.message },
    };
  }
  return {
    ok: true,
    values,
    data: {
      altText: alt.value,
      variantId: variant.value,
      sortOrder: sortOrder.value,
    },
  };
}

export function updateFormValuesFromImage(image: {
  altText: string | null;
  variantId: string | null;
  sortOrder: number;
}): UpdateMediaFormValues {
  return {
    altText: image.altText ?? "",
    variantId: image.variantId ?? "",
    sortOrder: String(image.sortOrder),
  };
}
