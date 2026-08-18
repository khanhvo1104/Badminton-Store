import { revalidatePath } from "next/cache";

import {
  PRODUCTS_LIST_PATH,
  PRODUCTS_NEW_PATH,
  productDetailPath,
  productEditPath,
} from "@/features/products/constants";

export { productDetailPath, productEditPath };

export function getProductRevalidationPaths(productId?: string): string[] {
  const paths = [PRODUCTS_LIST_PATH, PRODUCTS_NEW_PATH];
  if (productId) {
    paths.push(productDetailPath(productId), productEditPath(productId));
  }
  return paths;
}

export function revalidateProductPaths(productId?: string): void {
  for (const path of getProductRevalidationPaths(productId)) {
    revalidatePath(path);
  }
}
