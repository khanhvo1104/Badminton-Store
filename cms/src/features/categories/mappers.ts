import { buildCategoryImagePublicUrl } from "@/features/categories/image";
import type {
  CategoryDetail,
  CategoryListItem,
  CategoryParentOption,
} from "@/features/categories/types";
import { isValidUuid } from "@/features/categories/validation";

export type CategoryRow = {
  id: string;
  parent_id: string | null;
  name: string;
  slug: string;
  description: string | null;
  image_path: string | null;
  sort_order: number;
  is_active: boolean;
};

export type CategoryParentRow = {
  id: string;
  parent_id: string | null;
  name: string;
  is_active: boolean;
};

export function mapCategoryRow(value: unknown): CategoryRow | null {
  if (!isRecord(value)) {
    return null;
  }

  const id = value.id;
  const parentId = value.parent_id;
  const name = value.name;
  const slug = value.slug;
  const description = value.description;
  const imagePath = value.image_path;
  const sortOrder = value.sort_order;
  const isActive = value.is_active;

  if (typeof id !== "string" || !isValidUuid(id)) {
    return null;
  }
  if (parentId !== null && typeof parentId !== "string") {
    return null;
  }
  if (typeof parentId === "string" && !isValidUuid(parentId)) {
    return null;
  }
  if (typeof name !== "string" || typeof slug !== "string") {
    return null;
  }
  if (description !== null && typeof description !== "string") {
    return null;
  }
  if (imagePath !== null && typeof imagePath !== "string") {
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
    parent_id: parentId,
    name,
    slug,
    description,
    image_path: imagePath,
    sort_order: sortOrder,
    is_active: isActive,
  };
}

export function mapCategoryParentRow(value: unknown): CategoryParentRow | null {
  if (!isRecord(value)) {
    return null;
  }

  const id = value.id;
  const parentId = value.parent_id;
  const name = value.name;
  const isActive = value.is_active;

  if (typeof id !== "string" || !isValidUuid(id)) {
    return null;
  }
  if (parentId !== null && typeof parentId !== "string") {
    return null;
  }
  if (typeof parentId === "string" && !isValidUuid(parentId)) {
    return null;
  }
  if (typeof name !== "string") {
    return null;
  }
  if (typeof isActive !== "boolean") {
    return null;
  }

  return {
    id,
    parent_id: parentId,
    name,
    is_active: isActive,
  };
}

export function isCategoryRow(value: unknown): value is CategoryRow {
  return mapCategoryRow(value) !== null;
}

export function isCategoryParentRow(
  value: unknown,
): value is CategoryParentRow {
  return mapCategoryParentRow(value) !== null;
}

export function mapCategoryDetail(
  row: CategoryRow,
  supabaseUrl: string,
): CategoryDetail {
  return {
    id: row.id,
    parentId: row.parent_id,
    name: row.name,
    slug: row.slug,
    description: row.description,
    imagePath: row.image_path,
    imageUrl: buildCategoryImagePublicUrl(supabaseUrl, row.image_path),
    sortOrder: row.sort_order,
    isActive: row.is_active,
  };
}

export function mapCategoryListItem(
  row: CategoryRow,
  parentName: string | null,
  supabaseUrl: string,
): CategoryListItem {
  return {
    ...mapCategoryDetail(row, supabaseUrl),
    parentName,
  };
}

export function mapCategoryParentOption(
  row: CategoryParentRow,
): CategoryParentOption {
  return {
    id: row.id,
    parentId: row.parent_id,
    name: row.name,
    isActive: row.is_active,
  };
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null;
}
