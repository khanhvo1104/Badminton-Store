import {
  BRAND_COUNTRY_MAX_LENGTH,
  BRAND_DESCRIPTION_MAX_LENGTH,
  BRAND_NAME_MAX_LENGTH,
  BRAND_PAGE_SIZE_DEFAULT,
  BRAND_PAGE_SIZE_MAX,
  BRAND_SLUG_MAX_LENGTH,
  BRAND_SLUG_PATTERN,
  BRAND_SORT_ORDER_MAX,
  BRAND_SORT_ORDER_MIN,
  BRAND_WEBSITE_INVALID_MESSAGE,
  BRAND_WEBSITE_URL_MAX_LENGTH,
  UUID_PATTERN,
} from "@/features/brands/constants";
import type {
  BrandFieldErrors,
  BrandFormValues,
  BrandPagination,
  ParsedBrandInput,
} from "@/features/brands/types";

export function parseBrandPagination(
  searchParams:
    | Record<string, string | string[] | undefined>
    | URLSearchParams
    | {
        page?: string | string[] | undefined;
        pageSize?: string | string[] | undefined;
      },
): BrandPagination {
  const pageRaw = readSearchParam(searchParams, "page");
  const pageSizeRaw = readSearchParam(searchParams, "pageSize");

  const pageSize = clampInt(
    parseStrictPositiveInt(pageSizeRaw),
    1,
    BRAND_PAGE_SIZE_MAX,
    BRAND_PAGE_SIZE_DEFAULT,
  );
  const page = clampInt(parseStrictPositiveInt(pageRaw), 1, 1_000_000, 1);
  const from = (page - 1) * pageSize;
  const to = from + pageSize - 1;

  return { page, pageSize, from, to };
}

export function normalizeBrandSlug(raw: string): string {
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

export function parseAbsoluteHttpsUrl(raw: string): string | null {
  const trimmed = raw.trim();
  if (!trimmed) {
    return null;
  }

  if (
    trimmed.length > BRAND_WEBSITE_URL_MAX_LENGTH ||
    /\s/.test(trimmed) ||
    !trimmed.toLowerCase().startsWith("https://")
  ) {
    return null;
  }

  try {
    const parsed = new URL(trimmed);
    if (parsed.protocol !== "https:") {
      return null;
    }
    if (!parsed.hostname) {
      return null;
    }
    if (parsed.username || parsed.password) {
      return null;
    }
    return trimmed;
  } catch {
    return null;
  }
}

export function readBrandFormValues(formData: FormData): BrandFormValues {
  return {
    name: readTrimmed(formData, "name"),
    slug: readTrimmed(formData, "slug"),
    description: readString(formData, "description"),
    websiteUrl: readTrimmed(formData, "website_url"),
    countryOfOrigin: readTrimmed(formData, "country_of_origin"),
    sortOrder: readTrimmed(formData, "sort_order"),
    isActive: readCheckbox(formData, "is_active"),
  };
}

export function parseBrandFormInput(formData: FormData):
  | { ok: true; data: ParsedBrandInput; values: BrandFormValues }
  | {
      ok: false;
      fieldErrors: BrandFieldErrors;
      values: BrandFormValues;
      message: string;
    } {
  const values = readBrandFormValues(formData);
  const validated = validateBrandFormValues(values);

  if (!validated.ok) {
    return {
      ok: false,
      fieldErrors: validated.fieldErrors,
      values: {
        ...values,
        name: values.name.trim(),
        slug: normalizeBrandSlug(values.slug || values.name) || values.slug,
        websiteUrl: values.websiteUrl.trim(),
        countryOfOrigin: values.countryOfOrigin.trim(),
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
      websiteUrl: validated.data.websiteUrl ?? "",
      countryOfOrigin: validated.data.countryOfOrigin ?? "",
      sortOrder: String(validated.data.sortOrder),
      isActive: validated.data.isActive,
    },
    data: validated.data,
  };
}

export function validateBrandFormValues(
  values: BrandFormValues,
):
  | { ok: true; data: ParsedBrandInput }
  | { ok: false; fieldErrors: BrandFieldErrors } {
  const fieldErrors: BrandFieldErrors = {};
  const name = values.name.trim();
  const slugSource = values.slug.trim() ? values.slug : values.name;
  const slug = normalizeBrandSlug(slugSource);
  const description = values.description.trim();
  const websiteRaw = values.websiteUrl.trim();
  const country = values.countryOfOrigin.trim();
  const sortRaw = values.sortOrder.trim();

  if (!name) {
    fieldErrors.name = "Enter a brand name.";
  } else if (name.length > BRAND_NAME_MAX_LENGTH) {
    fieldErrors.name = `Name must be at most ${BRAND_NAME_MAX_LENGTH} characters.`;
  }

  if (!slug) {
    fieldErrors.slug =
      "Enter a URL slug using lowercase letters, numbers, and hyphens.";
  } else if (slug.length > BRAND_SLUG_MAX_LENGTH) {
    fieldErrors.slug = `Slug must be at most ${BRAND_SLUG_MAX_LENGTH} characters.`;
  } else if (!BRAND_SLUG_PATTERN.test(slug)) {
    fieldErrors.slug =
      "Slug must use lowercase letters, numbers, and single hyphens only.";
  }

  if (description.length > BRAND_DESCRIPTION_MAX_LENGTH) {
    fieldErrors.description = `Description must be at most ${BRAND_DESCRIPTION_MAX_LENGTH} characters.`;
  }

  let websiteUrl: string | null = null;
  if (websiteRaw) {
    const parsedWebsite = parseAbsoluteHttpsUrl(websiteRaw);
    if (!parsedWebsite) {
      fieldErrors.websiteUrl = BRAND_WEBSITE_INVALID_MESSAGE;
    } else {
      websiteUrl = parsedWebsite;
    }
  }

  let countryOfOrigin: string | null = null;
  if (country) {
    if (country.length > BRAND_COUNTRY_MAX_LENGTH) {
      fieldErrors.countryOfOrigin = `Country of origin must be at most ${BRAND_COUNTRY_MAX_LENGTH} characters.`;
    } else {
      countryOfOrigin = country;
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
      sortOrder < BRAND_SORT_ORDER_MIN ||
      sortOrder > BRAND_SORT_ORDER_MAX
    ) {
      fieldErrors.sortOrder = `Sort order must be between ${BRAND_SORT_ORDER_MIN} and ${BRAND_SORT_ORDER_MAX}.`;
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
      websiteUrl,
      countryOfOrigin,
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
