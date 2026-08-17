import {
  BRAND_GENERIC_FAILURE_MESSAGE,
  BRAND_LIST_COLUMNS,
  BRAND_NOT_FOUND_MESSAGE,
} from "@/features/brands/constants";
import {
  isBrandRow,
  mapBrandDetail,
  mapBrandListItem,
} from "@/features/brands/mappers";
import type {
  BrandDetail,
  BrandListResult,
  BrandPagination,
} from "@/features/brands/types";
import { isValidUuid } from "@/features/brands/validation";

export type BrandListQueryClient = {
  from: (table: "brands") => {
    select: (
      columns: string,
      options?: { count?: "exact"; head?: boolean },
    ) => BrandListBuilder;
  };
};

type BrandListBuilder = {
  order: (
    column: string,
    options?: { ascending?: boolean },
  ) => BrandListBuilder;
  range: (
    from: number,
    to: number,
  ) => PromiseLike<{
    data: unknown;
    error: unknown;
    count: number | null;
  }>;
};

export type BrandDetailQueryClient = {
  from: (table: "brands") => {
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

export async function listBrands(options: {
  supabase: BrandListQueryClient;
  pagination: BrandPagination;
  supabaseUrl: string;
}): Promise<
  { ok: true; result: BrandListResult } | { ok: false; message: string }
> {
  const { supabase, pagination, supabaseUrl } = options;

  try {
    const { data, error, count } = await supabase
      .from("brands")
      .select(BRAND_LIST_COLUMNS, { count: "exact" })
      .order("sort_order", { ascending: true })
      .order("name", { ascending: true })
      .order("id", { ascending: true })
      .range(pagination.from, pagination.to);

    if (error || !Array.isArray(data)) {
      return { ok: false, message: BRAND_GENERIC_FAILURE_MESSAGE };
    }

    const rows = data.filter(isBrandRow);
    if (rows.length !== data.length) {
      return { ok: false, message: BRAND_GENERIC_FAILURE_MESSAGE };
    }

    const totalCount = typeof count === "number" && count >= 0 ? count : 0;
    const totalPages =
      totalCount === 0 ? 0 : Math.ceil(totalCount / pagination.pageSize);

    return {
      ok: true,
      result: {
        items: rows.map((row) => mapBrandListItem(row, supabaseUrl)),
        totalCount,
        pagination,
        totalPages,
      },
    };
  } catch {
    return { ok: false, message: BRAND_GENERIC_FAILURE_MESSAGE };
  }
}

export async function getBrandById(options: {
  supabase: BrandDetailQueryClient;
  brandId: string;
  supabaseUrl: string;
}): Promise<
  | { ok: true; brand: BrandDetail }
  | { ok: false; message: string; notFound?: boolean }
> {
  const { supabase, brandId, supabaseUrl } = options;

  if (!isValidUuid(brandId)) {
    return {
      ok: false,
      message: BRAND_NOT_FOUND_MESSAGE,
      notFound: true,
    };
  }

  try {
    const { data, error } = await supabase
      .from("brands")
      .select(BRAND_LIST_COLUMNS)
      .eq("id", brandId)
      .maybeSingle();

    if (error) {
      return { ok: false, message: BRAND_GENERIC_FAILURE_MESSAGE };
    }

    if (data === null) {
      return {
        ok: false,
        message: BRAND_NOT_FOUND_MESSAGE,
        notFound: true,
      };
    }

    if (!isBrandRow(data)) {
      return { ok: false, message: BRAND_GENERIC_FAILURE_MESSAGE };
    }

    return {
      ok: true,
      brand: mapBrandDetail(data, supabaseUrl),
    };
  } catch {
    return { ok: false, message: BRAND_GENERIC_FAILURE_MESSAGE };
  }
}
