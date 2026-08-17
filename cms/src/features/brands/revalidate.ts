import { revalidatePath } from "next/cache";

import {
  BRANDS_LIST_PATH,
  BRANDS_NEW_PATH,
  brandEditPath,
} from "@/features/brands/constants";

export { brandEditPath };

export function getBrandRevalidationPaths(brandId?: string): string[] {
  const paths = [BRANDS_LIST_PATH, BRANDS_NEW_PATH];
  if (brandId) {
    paths.push(brandEditPath(brandId));
  }
  return paths;
}

export function revalidateBrandPaths(brandId?: string): void {
  for (const path of getBrandRevalidationPaths(brandId)) {
    revalidatePath(path);
  }
}
