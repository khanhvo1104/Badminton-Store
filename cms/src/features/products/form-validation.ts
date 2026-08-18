import {
  PRODUCT_CATEGORY_REQUIRED_MESSAGE,
  PRODUCT_DESCRIPTION_MAX_LENGTH,
  PRODUCT_NAME_MAX_LENGTH,
  PRODUCT_PUBLISHED_AT_INVALID_MESSAGE,
  PRODUCT_SEARCH_KEYWORDS_MAX_LENGTH,
  PRODUCT_SHORT_DESCRIPTION_MAX_LENGTH,
  PRODUCT_SLUG_MAX_LENGTH,
  PRODUCT_SLUG_PATTERN,
  PRODUCT_STATUSES,
  PRODUCT_STATUS_INVALID_MESSAGE,
} from "@/features/products/constants";
import {
  formatSpecificationsForForm,
  parseSpecificationsInput,
} from "@/features/products/specifications";
import type {
  ParsedProductInput,
  ProductFieldErrors,
  ProductFormValues,
  ProductStatus,
} from "@/features/products/types";
import { isValidUuid } from "@/features/products/validation";

export function normalizeProductSlug(raw: string): string {
  return raw
    .trim()
    .toLowerCase()
    .replace(/[\s_]+/g, "-")
    .replace(/[^a-z0-9-]/g, "")
    .replace(/-+/g, "-")
    .replace(/^-+|-+$/g, "");
}

export function suggestProductSlugFromName(name: string): string {
  return normalizeProductSlug(name);
}

export function readProductFormValues(formData: FormData): ProductFormValues {
  return {
    categoryId: readTrimmed(formData, "category_id"),
    brandId: readTrimmed(formData, "brand_id"),
    name: readTrimmed(formData, "name"),
    slug: readTrimmed(formData, "slug"),
    slugManual: readCheckbox(formData, "slug_manual"),
    shortDescription: readString(formData, "short_description"),
    description: readString(formData, "description"),
    specifications: readString(formData, "specifications"),
    searchKeywords: readTrimmed(formData, "search_keywords"),
    status: readTrimmed(formData, "status"),
    isFeatured: readCheckbox(formData, "is_featured"),
    publishedAt: readTrimmed(formData, "published_at"),
  };
}

export function parseProductFormInput(
  formData: FormData,
  options: {
    existingPublishedAt?: string | null;
    now?: () => Date;
  } = {},
): ParseProductFormResult {
  const values = readProductFormValues(formData);
  const validated = validateProductFormValues(values, options);

  if (!validated.ok) {
    return {
      ok: false,
      fieldErrors: validated.fieldErrors,
      values: preserveSafeProductValues(values),
      message: "Fix the highlighted fields and try again.",
    };
  }

  return {
    ok: true,
    values: {
      ...values,
      name: validated.data.name,
      slug: validated.data.slug,
      categoryId: validated.data.categoryId,
      brandId: validated.data.brandId ?? "",
      shortDescription: validated.data.shortDescription ?? "",
      description: validated.data.description ?? "",
      specifications: formatSpecificationsForForm(
        validated.data.specifications,
      ),
      searchKeywords: validated.data.searchKeywords ?? "",
      status: validated.data.status,
      isFeatured: validated.data.isFeatured,
      publishedAt: toDatetimeLocalValue(validated.data.publishedAt),
    },
    data: validated.data,
  };
}

export function validateProductFormValues(
  values: ProductFormValues,
  options: {
    existingPublishedAt?: string | null;
    now?: () => Date;
  } = {},
):
  | { ok: true; data: ParsedProductInput }
  | { ok: false; fieldErrors: ProductFieldErrors } {
  const fieldErrors: ProductFieldErrors = {};
  const name = values.name.trim();
  const slugSource =
    values.slug.trim() ||
    (values.slugManual ? "" : suggestProductSlugFromName(values.name));
  const slug = normalizeProductSlug(slugSource);
  const categoryRaw = values.categoryId.trim();
  const brandRaw = values.brandId.trim();
  const shortDescription = values.shortDescription.trim();
  const description = values.description.trim();
  const searchKeywords = values.searchKeywords.trim();
  const publishedAtRaw = values.publishedAt.trim();
  const statusRaw = values.status.trim();

  if (!name) {
    fieldErrors.name = "Enter a product name.";
  } else if (name.length > PRODUCT_NAME_MAX_LENGTH) {
    fieldErrors.name = `Name must be at most ${PRODUCT_NAME_MAX_LENGTH} characters.`;
  }

  if (!slug) {
    fieldErrors.slug =
      "Enter a URL slug using lowercase letters, numbers, and hyphens.";
  } else if (slug.length > PRODUCT_SLUG_MAX_LENGTH) {
    fieldErrors.slug = `Slug must be at most ${PRODUCT_SLUG_MAX_LENGTH} characters.`;
  } else if (!PRODUCT_SLUG_PATTERN.test(slug)) {
    fieldErrors.slug =
      "Slug must use lowercase letters, numbers, and single hyphens only.";
  }

  if (!categoryRaw) {
    fieldErrors.categoryId = PRODUCT_CATEGORY_REQUIRED_MESSAGE;
  } else if (!isValidUuid(categoryRaw)) {
    fieldErrors.categoryId = PRODUCT_CATEGORY_REQUIRED_MESSAGE;
  }

  let brandId: string | null = null;
  if (brandRaw) {
    if (!isValidUuid(brandRaw)) {
      fieldErrors.brandId = "Choose a valid brand, or leave brand empty.";
    } else {
      brandId = brandRaw;
    }
  }

  if (shortDescription.length > PRODUCT_SHORT_DESCRIPTION_MAX_LENGTH) {
    fieldErrors.shortDescription = `Short description must be at most ${PRODUCT_SHORT_DESCRIPTION_MAX_LENGTH} characters.`;
  }

  if (description.length > PRODUCT_DESCRIPTION_MAX_LENGTH) {
    fieldErrors.description = `Description must be at most ${PRODUCT_DESCRIPTION_MAX_LENGTH} characters.`;
  }

  if (searchKeywords.length > PRODUCT_SEARCH_KEYWORDS_MAX_LENGTH) {
    fieldErrors.searchKeywords = `Search keywords must be at most ${PRODUCT_SEARCH_KEYWORDS_MAX_LENGTH} characters.`;
  }

  const specifications = parseSpecificationsInput(values.specifications);
  if (!specifications.ok) {
    fieldErrors.specifications = specifications.message;
  }

  let status: ProductStatus | null = null;
  if (!statusRaw) {
    fieldErrors.status = PRODUCT_STATUS_INVALID_MESSAGE;
  } else if (!isProductStatus(statusRaw)) {
    fieldErrors.status = PRODUCT_STATUS_INVALID_MESSAGE;
  } else {
    status = statusRaw;
  }

  let publishedAt: string | null | undefined = null;
  if (status) {
    publishedAt = resolvePublishedAt({
      status,
      publishedAtRaw,
      existingPublishedAt: options.existingPublishedAt,
      now: options.now ?? (() => new Date()),
      fieldErrors,
    });
  }

  if (Object.keys(fieldErrors).length > 0) {
    return { ok: false, fieldErrors };
  }

  if (!categoryRaw || !isValidUuid(categoryRaw)) {
    return { ok: false, fieldErrors };
  }

  if (!specifications.ok) {
    return { ok: false, fieldErrors };
  }

  if (publishedAt === undefined || status === null) {
    return { ok: false, fieldErrors };
  }

  return {
    ok: true,
    data: {
      categoryId: categoryRaw,
      brandId,
      name,
      slug,
      shortDescription: shortDescription.length > 0 ? shortDescription : null,
      description: description.length > 0 ? description : null,
      specifications: specifications.value,
      searchKeywords: searchKeywords.length > 0 ? searchKeywords : null,
      status,
      isFeatured: values.isFeatured,
      publishedAt,
    },
  };
}

export function buildProductMutationPayload(
  data: ParsedProductInput,
): import("@/features/products/types").ProductMutationPayload {
  return {
    category_id: data.categoryId,
    brand_id: data.brandId,
    name: data.name,
    slug: data.slug,
    short_description: data.shortDescription,
    description: data.description,
    specifications: data.specifications,
    search_keywords: data.searchKeywords,
    status: data.status,
    is_featured: data.isFeatured,
    published_at: data.publishedAt,
  };
}

export function preserveSafeProductValues(
  values: ProductFormValues,
): ProductFormValues {
  return {
    ...values,
    name: values.name.trim(),
    slug:
      normalizeProductSlug(values.slug || values.name) || values.slug.trim(),
    categoryId: values.categoryId.trim(),
    brandId: values.brandId.trim(),
    searchKeywords: values.searchKeywords.trim(),
    status: values.status.trim(),
    publishedAt: values.publishedAt.trim(),
  };
}

export function toDatetimeLocalValue(value: string | null): string {
  if (!value) {
    return "";
  }

  const date = new Date(value);
  if (Number.isNaN(date.getTime())) {
    return "";
  }

  const pad = (part: number) => String(part).padStart(2, "0");
  return `${date.getUTCFullYear()}-${pad(date.getUTCMonth() + 1)}-${pad(date.getUTCDate())}T${pad(date.getUTCHours())}:${pad(date.getUTCMinutes())}`;
}

type ParseProductFormResult =
  | { ok: true; data: ParsedProductInput; values: ProductFormValues }
  | {
      ok: false;
      fieldErrors: ProductFieldErrors;
      values: ProductFormValues;
      message: string;
    };

function resolvePublishedAt(options: {
  status: ProductStatus;
  publishedAtRaw: string;
  existingPublishedAt?: string | null;
  now: () => Date;
  fieldErrors: ProductFieldErrors;
}): string | null | undefined {
  const { status, publishedAtRaw, existingPublishedAt, now, fieldErrors } =
    options;

  if (status === "active") {
    if (publishedAtRaw) {
      const parsed = parseDatetimeLocalValue(publishedAtRaw);
      if (!parsed) {
        fieldErrors.publishedAt = PRODUCT_PUBLISHED_AT_INVALID_MESSAGE;
        return undefined;
      }
      return parsed;
    }

    if (existingPublishedAt) {
      return existingPublishedAt;
    }

    return now().toISOString();
  }

  if (!publishedAtRaw) {
    return null;
  }

  const parsed = parseDatetimeLocalValue(publishedAtRaw);
  if (!parsed) {
    fieldErrors.publishedAt = PRODUCT_PUBLISHED_AT_INVALID_MESSAGE;
    return undefined;
  }

  return parsed;
}

function parseDatetimeLocalValue(raw: string): string | null {
  if (!/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}$/.test(raw)) {
    return null;
  }

  const date = new Date(`${raw}:00.000Z`);
  if (Number.isNaN(date.getTime())) {
    return null;
  }

  return date.toISOString();
}

function isProductStatus(value: string): value is ProductStatus {
  return (PRODUCT_STATUSES as readonly string[]).includes(value);
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
