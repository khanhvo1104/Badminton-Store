import { buildBrandLogoPublicUrl } from "@/features/brands/logo";
import type { BrandDetail, BrandListItem } from "@/features/brands/types";
import { isValidUuid } from "@/features/brands/validation";

export type BrandRow = {
  id: string;
  name: string;
  slug: string;
  description: string | null;
  logo_path: string | null;
  website_url: string | null;
  country_of_origin: string | null;
  sort_order: number;
  is_active: boolean;
};

export function mapBrandRow(value: unknown): BrandRow | null {
  if (!isRecord(value)) {
    return null;
  }

  const id = value.id;
  const name = value.name;
  const slug = value.slug;
  const description = value.description;
  const logoPath = value.logo_path;
  const websiteUrl = value.website_url;
  const countryOfOrigin = value.country_of_origin;
  const sortOrder = value.sort_order;
  const isActive = value.is_active;

  if (typeof id !== "string" || !isValidUuid(id)) {
    return null;
  }
  if (typeof name !== "string" || typeof slug !== "string") {
    return null;
  }
  if (description !== null && typeof description !== "string") {
    return null;
  }
  if (logoPath !== null && typeof logoPath !== "string") {
    return null;
  }
  if (websiteUrl !== null && typeof websiteUrl !== "string") {
    return null;
  }
  if (countryOfOrigin !== null && typeof countryOfOrigin !== "string") {
    return null;
  }
  if (typeof sortOrder !== "number" || !Number.isFinite(sortOrder)) {
    return null;
  }
  if (typeof isActive !== "boolean") {
    return null;
  }

  return {
    id,
    name,
    slug,
    description,
    logo_path: logoPath,
    website_url: websiteUrl,
    country_of_origin: countryOfOrigin,
    sort_order: sortOrder,
    is_active: isActive,
  };
}

export function isBrandRow(value: unknown): value is BrandRow {
  return mapBrandRow(value) !== null;
}

export function mapBrandDetail(
  row: BrandRow,
  supabaseUrl: string,
): BrandDetail {
  return {
    id: row.id,
    name: row.name,
    slug: row.slug,
    description: row.description,
    logoPath: row.logo_path,
    logoUrl: buildBrandLogoPublicUrl(supabaseUrl, row.logo_path),
    websiteUrl: row.website_url,
    countryOfOrigin: row.country_of_origin,
    sortOrder: row.sort_order,
    isActive: row.is_active,
  };
}

export function mapBrandListItem(
  row: BrandRow,
  supabaseUrl: string,
): BrandListItem {
  return mapBrandDetail(row, supabaseUrl);
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null;
}
