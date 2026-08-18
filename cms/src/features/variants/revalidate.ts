import { revalidatePath } from "next/cache";

import {
  PRODUCTS_LIST_PATH,
  productDetailPath,
  productEditPath,
} from "@/features/products/constants";
import {
  productVariantEditPath,
  productVariantNewPath,
  productVariantsPath,
} from "@/features/variants/constants";

export function getVariantRevalidationPaths(
  productId: string,
  variantId?: string,
): string[] {
  const paths = [
    PRODUCTS_LIST_PATH,
    productDetailPath(productId),
    productEditPath(productId),
    productVariantsPath(productId),
    productVariantNewPath(productId),
  ];
  if (variantId) {
    paths.push(productVariantEditPath(productId, variantId));
  }
  return paths;
}

export function revalidateVariantPaths(
  productId: string,
  variantId?: string,
): void {
  for (const path of getVariantRevalidationPaths(productId, variantId)) {
    revalidatePath(path);
  }
}
