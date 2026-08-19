import {
  MEDIA_AUTH_DENIED_MESSAGE,
  MEDIA_LOAD_FAILURE_MESSAGE,
  MEDIA_PRODUCT_NOT_FOUND_MESSAGE,
  PRODUCT_IMAGE_LIST_COLUMNS,
  PRODUCT_IMAGE_MAX_COUNT,
  PRODUCT_IMAGE_VARIANT_COLUMNS,
} from "@/features/media/constants";
import { sanitizeMediaProviderError } from "@/features/media/errors";
import {
  mapProductImageRow,
  mapProductMediaVariantRow,
  toProductMediaImage,
  toProductMediaVariantOption,
} from "@/features/media/mappers";
import type {
  ProductMediaImage,
  ProductMediaPageData,
  ProductMediaVariantOption,
} from "@/features/media/types";
import { isValidUuid } from "@/features/media/validation";
import {
  getProductById,
  type ProductDetailQueryClient,
} from "@/features/products/detail-queries";
import { VARIANT_LIST_MAX } from "@/features/variants/constants";
import {
  type AuthorizationSupabaseClient,
  authorizeCmsRequest,
} from "@/lib/auth/authorization";

type QueryResponse = {
  data: unknown;
  error: unknown;
};

export type MediaQueryClient = {
  auth: AuthorizationSupabaseClient["auth"];
  from: (
    table:
      | "products"
      | "categories"
      | "brands"
      | "product_images"
      | "product_variants",
  ) => {
    select: (columns: string) => MediaSelectBuilder;
  };
};

type MediaSelectBuilder = {
  eq: (
    column: "id" | "product_id",
    value: string,
  ) => {
    maybeSingle: () => PromiseLike<QueryResponse>;
    order: (
      column: string,
      options?: { ascending?: boolean },
    ) => MediaOrderedBuilder;
  };
  order: (
    column: string,
    options?: { ascending?: boolean },
  ) => MediaOrderedBuilder;
};

type MediaOrderedBuilder = {
  order: (
    column: string,
    options?: { ascending?: boolean },
  ) => MediaOrderedBuilder;
  limit: (count: number) => PromiseLike<QueryResponse>;
};

export async function getProductMediaPage(options: {
  supabase: MediaQueryClient;
  productId: string;
  supabaseUrl: string;
}): Promise<
  | { ok: true; data: ProductMediaPageData }
  | { ok: false; message: string; notFound?: boolean }
> {
  const { supabase, productId, supabaseUrl } = options;

  if (!isValidUuid(productId)) {
    return {
      ok: false,
      message: MEDIA_PRODUCT_NOT_FOUND_MESSAGE,
      notFound: true,
    };
  }

  try {
    const authorization = await authorizeCmsRequest(
      supabase as unknown as AuthorizationSupabaseClient,
    );
    if (authorization.kind !== "authorized") {
      return { ok: false, message: MEDIA_AUTH_DENIED_MESSAGE };
    }

    const productResult = await getProductById({
      supabase: supabase as unknown as ProductDetailQueryClient,
      productId,
    });
    if (!productResult.ok && productResult.notFound) {
      return {
        ok: false,
        message: MEDIA_PRODUCT_NOT_FOUND_MESSAGE,
        notFound: true,
      };
    }
    if (!productResult.ok) {
      return { ok: false, message: productResult.message };
    }

    const imagesResult = await loadProductImages(supabase, productId);
    if (!imagesResult.ok) {
      return { ok: false, message: imagesResult.message };
    }

    const variantsResult = await loadProductVariants(supabase, productId);
    if (!variantsResult.ok) {
      return { ok: false, message: variantsResult.message };
    }

    const variantLabelById = new Map(
      variantsResult.variants.map((variant) => [variant.id, variant.label]),
    );

    return {
      ok: true,
      data: {
        productId: productResult.product.id,
        productName: productResult.product.name,
        images: imagesResult.rows.map((row) =>
          toProductMediaImage({
            row,
            supabaseUrl,
            variantLabelById,
          }),
        ),
        variants: variantsResult.variants,
      },
    };
  } catch {
    return { ok: false, message: MEDIA_LOAD_FAILURE_MESSAGE };
  }
}

export async function loadProductImages(
  supabase: MediaQueryClient,
  productId: string,
): Promise<
  | { ok: true; rows: NonNullable<ReturnType<typeof mapProductImageRow>>[] }
  | { ok: false; message: string }
> {
  try {
    const { data, error } = await supabase
      .from("product_images")
      .select(PRODUCT_IMAGE_LIST_COLUMNS)
      .eq("product_id", productId)
      .order("sort_order", { ascending: true })
      .order("id", { ascending: true })
      .limit(PRODUCT_IMAGE_MAX_COUNT + 1);

    if (error || !Array.isArray(data)) {
      return { ok: false, message: sanitizeMediaProviderError(error) };
    }
    if (data.length > PRODUCT_IMAGE_MAX_COUNT) {
      return { ok: false, message: MEDIA_LOAD_FAILURE_MESSAGE };
    }

    const rows = [];
    for (const value of data) {
      const mapped = mapProductImageRow(value);
      if (!mapped || mapped.product_id !== productId) {
        return { ok: false, message: MEDIA_LOAD_FAILURE_MESSAGE };
      }
      rows.push(mapped);
    }
    return { ok: true, rows };
  } catch {
    return { ok: false, message: MEDIA_LOAD_FAILURE_MESSAGE };
  }
}

async function loadProductVariants(
  supabase: MediaQueryClient,
  productId: string,
): Promise<
  | { ok: true; variants: ProductMediaVariantOption[] }
  | { ok: false; message: string }
> {
  try {
    const { data, error } = await supabase
      .from("product_variants")
      .select(PRODUCT_IMAGE_VARIANT_COLUMNS)
      .eq("product_id", productId)
      .order("sort_order", { ascending: true })
      .order("id", { ascending: true })
      .limit(VARIANT_LIST_MAX + 1);

    if (error || !Array.isArray(data)) {
      return { ok: false, message: sanitizeMediaProviderError(error) };
    }
    if (data.length > VARIANT_LIST_MAX) {
      return { ok: false, message: MEDIA_LOAD_FAILURE_MESSAGE };
    }

    const variants: ProductMediaVariantOption[] = [];
    for (const value of data) {
      const mapped = mapProductMediaVariantRow(value);
      if (!mapped) {
        return { ok: false, message: MEDIA_LOAD_FAILURE_MESSAGE };
      }
      variants.push(toProductMediaVariantOption(mapped));
    }
    return { ok: true, variants };
  } catch {
    return { ok: false, message: MEDIA_LOAD_FAILURE_MESSAGE };
  }
}

export function sameScopeImages(
  images: ProductMediaImage[],
  image: ProductMediaImage,
): ProductMediaImage[] {
  return images.filter((candidate) => candidate.variantId === image.variantId);
}

export function nextPrimaryCandidate(
  images: ProductMediaImage[],
  deleted: ProductMediaImage,
): ProductMediaImage | null {
  const remaining = sameScopeImages(images, deleted).filter(
    (candidate) => candidate.id !== deleted.id,
  );
  return remaining[0] ?? null;
}
