import { revalidatePath } from "next/cache";

import { productMediaPath } from "@/features/media/constants";
import {
  PRODUCTS_LIST_PATH,
  productDetailPath,
  productEditPath,
} from "@/features/products/constants";

export function getMediaRevalidationPaths(productId: string): string[] {
  return [
    PRODUCTS_LIST_PATH,
    productDetailPath(productId),
    productEditPath(productId),
    productMediaPath(productId),
  ];
}

export function revalidateMediaPaths(productId: string): void {
  for (const path of getMediaRevalidationPaths(productId)) {
    revalidatePath(path);
  }
}
