import {
  CATEGORY_GENERIC_FAILURE_MESSAGE,
  CATEGORY_GRAPH_FETCH_LIMIT,
  CATEGORY_LIST_COLUMNS,
  CATEGORY_NOT_FOUND_MESSAGE,
  CATEGORY_PARENT_OPTION_COLUMNS,
} from "@/features/categories/constants";
import { clampCategoryGraphLimit } from "@/features/categories/hierarchy";
import {
  isCategoryParentRow,
  isCategoryRow,
  mapCategoryDetail,
  mapCategoryListItem,
  mapCategoryParentOption,
} from "@/features/categories/mappers";
import type {
  CategoryDetail,
  CategoryListResult,
  CategoryPagination,
  CategoryParentOption,
} from "@/features/categories/types";
import { isValidUuid } from "@/features/categories/validation";

export type CategoryListQueryClient = {
  from: (table: "categories") => {
    select: (
      columns: string,
      options?: { count?: "exact"; head?: boolean },
    ) => CategoryListBuilder;
  };
};

type CategoryListBuilder = {
  order: (
    column: string,
    options?: { ascending?: boolean },
  ) => CategoryListBuilder;
  range: (
    from: number,
    to: number,
  ) => PromiseLike<{
    data: unknown;
    error: unknown;
    count: number | null;
  }>;
};

export type CategoryDetailQueryClient = {
  from: (table: "categories") => {
    select: (columns: string) => {
      eq: (
        column: "id",
        value: string,
      ) => {
        maybeSingle: () => PromiseLike<{ data: unknown; error: unknown }>;
      };
    };
  };
};

export type CategoryParentOptionsQueryClient = {
  from: (table: "categories") => {
    select: (columns: string) => {
      order: (
        column: string,
        options?: { ascending?: boolean },
      ) => CategoryParentOptionsBuilder;
    };
  };
};

type CategoryParentOptionsBuilder = {
  order: (
    column: string,
    options?: { ascending?: boolean },
  ) => CategoryParentOptionsBuilder;
  limit: (count: number) => PromiseLike<{ data: unknown; error: unknown }>;
};

export type CategoryNamesQueryClient = {
  from: (table: "categories") => {
    select: (columns: string) => {
      in: (
        column: "id",
        values: string[],
      ) => PromiseLike<{ data: unknown; error: unknown }>;
    };
  };
};

export async function listCategories(options: {
  supabase: CategoryListQueryClient & CategoryNamesQueryClient;
  pagination: CategoryPagination;
  supabaseUrl: string;
}): Promise<
  { ok: true; result: CategoryListResult } | { ok: false; message: string }
> {
  const { supabase, pagination, supabaseUrl } = options;

  try {
    const { data, error, count } = await supabase
      .from("categories")
      .select(CATEGORY_LIST_COLUMNS, { count: "exact" })
      .order("sort_order", { ascending: true })
      .order("name", { ascending: true })
      .order("id", { ascending: true })
      .range(pagination.from, pagination.to);

    if (error || !Array.isArray(data)) {
      return { ok: false, message: CATEGORY_GENERIC_FAILURE_MESSAGE };
    }

    const rows = data.filter(isCategoryRow);
    if (rows.length !== data.length) {
      return { ok: false, message: CATEGORY_GENERIC_FAILURE_MESSAGE };
    }

    const parentIds = [
      ...new Set(
        rows
          .map((row) => row.parent_id)
          .filter((value): value is string => typeof value === "string"),
      ),
    ];

    const parentNameById = await loadParentNames(supabase, parentIds);
    if (parentNameById === null) {
      return { ok: false, message: CATEGORY_GENERIC_FAILURE_MESSAGE };
    }

    const totalCount = typeof count === "number" && count >= 0 ? count : 0;
    const totalPages =
      totalCount === 0 ? 0 : Math.ceil(totalCount / pagination.pageSize);

    return {
      ok: true,
      result: {
        items: rows.map((row) =>
          mapCategoryListItem(
            row,
            row.parent_id ? (parentNameById.get(row.parent_id) ?? null) : null,
            supabaseUrl,
          ),
        ),
        totalCount,
        pagination,
        totalPages,
      },
    };
  } catch {
    return { ok: false, message: CATEGORY_GENERIC_FAILURE_MESSAGE };
  }
}

export async function getCategoryById(options: {
  supabase: CategoryDetailQueryClient;
  categoryId: string;
  supabaseUrl: string;
}): Promise<
  | { ok: true; category: CategoryDetail }
  | { ok: false; message: string; notFound?: boolean }
> {
  const { supabase, categoryId, supabaseUrl } = options;

  if (!isValidUuid(categoryId)) {
    return {
      ok: false,
      message: CATEGORY_NOT_FOUND_MESSAGE,
      notFound: true,
    };
  }

  try {
    const { data, error } = await supabase
      .from("categories")
      .select(CATEGORY_LIST_COLUMNS)
      .eq("id", categoryId)
      .maybeSingle();

    if (error) {
      return { ok: false, message: CATEGORY_GENERIC_FAILURE_MESSAGE };
    }

    if (data === null) {
      return {
        ok: false,
        message: CATEGORY_NOT_FOUND_MESSAGE,
        notFound: true,
      };
    }

    if (!isCategoryRow(data)) {
      return { ok: false, message: CATEGORY_GENERIC_FAILURE_MESSAGE };
    }

    return {
      ok: true,
      category: mapCategoryDetail(data, supabaseUrl),
    };
  } catch {
    return { ok: false, message: CATEGORY_GENERIC_FAILURE_MESSAGE };
  }
}

export async function listCategoryParentOptions(options: {
  supabase: CategoryParentOptionsQueryClient;
  excludeCategoryId?: string;
}): Promise<
  { ok: true; options: CategoryParentOption[] } | { ok: false; message: string }
> {
  const { supabase, excludeCategoryId } = options;

  try {
    const { data, error } = await supabase
      .from("categories")
      .select(CATEGORY_PARENT_OPTION_COLUMNS)
      .order("name", { ascending: true })
      .order("id", { ascending: true })
      .limit(clampCategoryGraphLimit(CATEGORY_GRAPH_FETCH_LIMIT));

    if (error || !Array.isArray(data)) {
      return { ok: false, message: CATEGORY_GENERIC_FAILURE_MESSAGE };
    }

    const rows = data.filter(isCategoryParentRow);
    if (rows.length !== data.length) {
      return { ok: false, message: CATEGORY_GENERIC_FAILURE_MESSAGE };
    }

    return {
      ok: true,
      options: rows
        .filter((row) => row.id !== excludeCategoryId)
        .map(mapCategoryParentOption),
    };
  } catch {
    return { ok: false, message: CATEGORY_GENERIC_FAILURE_MESSAGE };
  }
}

async function loadParentNames(
  supabase: CategoryNamesQueryClient,
  parentIds: string[],
): Promise<Map<string, string> | null> {
  const map = new Map<string, string>();
  if (parentIds.length === 0) {
    return map;
  }

  try {
    const { data, error } = await supabase
      .from("categories")
      .select("id, name")
      .in("id", parentIds);

    if (error || !Array.isArray(data)) {
      return null;
    }

    for (const row of data) {
      if (
        isRecord(row) &&
        typeof row.id === "string" &&
        typeof row.name === "string"
      ) {
        map.set(row.id, row.name);
      }
    }

    return map;
  } catch {
    return null;
  }
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null;
}
