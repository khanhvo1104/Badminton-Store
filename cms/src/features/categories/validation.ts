import {
  CATEGORY_DESCRIPTION_MAX_LENGTH,
  CATEGORY_NAME_MAX_LENGTH,
  CATEGORY_PAGE_SIZE_DEFAULT,
  CATEGORY_PAGE_SIZE_MAX,
  CATEGORY_SLUG_MAX_LENGTH,
  CATEGORY_SLUG_PATTERN,
  CATEGORY_SORT_ORDER_MAX,
  CATEGORY_SORT_ORDER_MIN,
  UUID_PATTERN,
} from "@/features/categories/constants";
import type {
  CategoryFieldErrors,
  CategoryFormValues,
  CategoryPagination,
  ParsedCategoryInput,
} from "@/features/categories/types";

export function parseCategoryPagination(
  searchParams:
    | Record<string, string | string[] | undefined>
    | URLSearchParams
    | {
        page?: string | string[] | undefined;
        pageSize?: string | string[] | undefined;
      },
): CategoryPagination {
  const pageRaw = readSearchParam(searchParams, "page");
  const pageSizeRaw = readSearchParam(searchParams, "pageSize");

  const pageSize = clampInt(
    parseStrictPositiveInt(pageSizeRaw),
    1,
    CATEGORY_PAGE_SIZE_MAX,
    CATEGORY_PAGE_SIZE_DEFAULT,
  );
  const page = clampInt(parseStrictPositiveInt(pageRaw), 1, 1_000_000, 1);
  const from = (page - 1) * pageSize;
  const to = from + pageSize - 1;

  return { page, pageSize, from, to };
}

export function normalizeCategorySlug(raw: string): string {
  return raw
    .trim()
    .toLowerCase()
    .replace(/[\s_]+/g, "-")
    .replace(/[^a-z0-9-]/g, "")
    .replace(/-+/g, "-")
    .replace(/^-+|-+$/g, "");
}

export function isValidUuid(value: string): boolean {
  return UUID_PATTERN.test(value);
}

export function readCategoryFormValues(formData: FormData): CategoryFormValues {
  return {
    name: readTrimmed(formData, "name"),
    slug: readTrimmed(formData, "slug"),
    description: readString(formData, "description"),
    parentId: readTrimmed(formData, "parent_id"),
    sortOrder: readTrimmed(formData, "sort_order"),
    isActive: readCheckbox(formData, "is_active"),
  };
}

export function parseCategoryFormInput(formData: FormData):
  | { ok: true; data: ParsedCategoryInput; values: CategoryFormValues }
  | {
      ok: false;
      fieldErrors: CategoryFieldErrors;
      values: CategoryFormValues;
      message: string;
    } {
  const values = readCategoryFormValues(formData);
  const validated = validateCategoryFormValues(values);

  if (!validated.ok) {
    return {
      ok: false,
      fieldErrors: validated.fieldErrors,
      values: {
        ...values,
        name: values.name.trim(),
        slug: normalizeCategorySlug(values.slug || values.name) || values.slug,
        sortOrder: values.sortOrder.trim() || "0",
      },
      message: "Fix the highlighted fields and try again.",
    };
  }

  return {
    ok: true,
    values: {
      ...values,
      name: validated.data.name,
      slug: validated.data.slug,
      sortOrder: String(validated.data.sortOrder),
      isActive: validated.data.isActive,
    },
    data: validated.data,
  };
}

export function validateCategoryFormValues(
  values: CategoryFormValues,
):
  | { ok: true; data: ParsedCategoryInput }
  | { ok: false; fieldErrors: CategoryFieldErrors } {
  const fieldErrors: CategoryFieldErrors = {};
  const name = values.name.trim();
  const slugSource = values.slug.trim() ? values.slug : values.name;
  const slug = normalizeCategorySlug(slugSource);
  const description = values.description.trim();
  const parentRaw = values.parentId.trim();
  const sortRaw = values.sortOrder.trim();

  if (!name) {
    fieldErrors.name = "Enter a category name.";
  } else if (name.length > CATEGORY_NAME_MAX_LENGTH) {
    fieldErrors.name = `Name must be at most ${CATEGORY_NAME_MAX_LENGTH} characters.`;
  }

  if (!slug) {
    fieldErrors.slug =
      "Enter a URL slug using lowercase letters, numbers, and hyphens.";
  } else if (slug.length > CATEGORY_SLUG_MAX_LENGTH) {
    fieldErrors.slug = `Slug must be at most ${CATEGORY_SLUG_MAX_LENGTH} characters.`;
  } else if (!CATEGORY_SLUG_PATTERN.test(slug)) {
    fieldErrors.slug =
      "Slug must use lowercase letters, numbers, and single hyphens only.";
  }

  if (description.length > CATEGORY_DESCRIPTION_MAX_LENGTH) {
    fieldErrors.description = `Description must be at most ${CATEGORY_DESCRIPTION_MAX_LENGTH} characters.`;
  }

  let parentId: string | null = null;
  if (parentRaw) {
    if (!isValidUuid(parentRaw)) {
      fieldErrors.parentId =
        "Choose a valid parent category, or leave parent empty.";
    } else {
      parentId = parentRaw;
    }
  }

  let sortOrder = 0;
  if (!sortRaw) {
    fieldErrors.sortOrder = "Sort order must be a whole number.";
  } else if (!/^-?\d+$/.test(sortRaw)) {
    fieldErrors.sortOrder = "Sort order must be a whole number.";
  } else {
    sortOrder = Number(sortRaw);
    if (
      !Number.isSafeInteger(sortOrder) ||
      sortOrder < CATEGORY_SORT_ORDER_MIN ||
      sortOrder > CATEGORY_SORT_ORDER_MAX
    ) {
      fieldErrors.sortOrder = `Sort order must be between ${CATEGORY_SORT_ORDER_MIN} and ${CATEGORY_SORT_ORDER_MAX}.`;
    }
  }

  if (Object.keys(fieldErrors).length > 0) {
    return { ok: false, fieldErrors };
  }

  return {
    ok: true,
    data: {
      name,
      slug,
      description: description.length > 0 ? description : null,
      parentId,
      sortOrder,
      isActive: values.isActive,
    },
  };
}

function readSearchParam(
  searchParams:
    | Record<string, string | string[] | undefined>
    | URLSearchParams
    | {
        page?: string | string[] | undefined;
        pageSize?: string | string[] | undefined;
      },
  key: string,
): string | undefined {
  if (searchParams instanceof URLSearchParams) {
    return searchParams.get(key) ?? undefined;
  }

  const value = (searchParams as Record<string, string | string[] | undefined>)[
    key
  ];
  if (Array.isArray(value)) {
    return value[0];
  }
  return value;
}

function parseStrictPositiveInt(raw: string | undefined): number | null {
  if (raw === undefined) {
    return null;
  }
  const trimmed = raw.trim();
  if (!/^[1-9]\d*$/.test(trimmed)) {
    return null;
  }
  const value = Number(trimmed);
  return Number.isSafeInteger(value) ? value : null;
}

function clampInt(
  value: number | null,
  min: number,
  max: number,
  fallback: number,
): number {
  if (value === null) {
    return fallback;
  }
  return Math.min(max, Math.max(min, value));
}

function readTrimmed(formData: FormData, key: string): string {
  const value = formData.get(key);
  return typeof value === "string" ? value.trim() : "";
}

function readString(formData: FormData, key: string): string {
  const value = formData.get(key);
  return typeof value === "string" ? value : "";
}

function readCheckbox(formData: FormData, key: string): boolean {
  const value = formData.get(key);
  if (typeof value !== "string") {
    return false;
  }
  const normalized = value.trim().toLowerCase();
  return (
    normalized === "on" ||
    normalized === "true" ||
    normalized === "1" ||
    normalized === "yes"
  );
}
