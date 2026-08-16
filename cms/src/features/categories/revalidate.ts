import { revalidatePath } from "next/cache";

import {
  CATEGORIES_LIST_PATH,
  CATEGORIES_NEW_PATH,
  categoryEditPath,
} from "@/features/categories/constants";

export { categoryEditPath };

export function getCategoryRevalidationPaths(categoryId?: string): string[] {
  const paths = [CATEGORIES_LIST_PATH, CATEGORIES_NEW_PATH];
  if (categoryId) {
    paths.push(categoryEditPath(categoryId));
  }
  return paths;
}

export function revalidateCategoryPaths(categoryId?: string): void {
  for (const path of getCategoryRevalidationPaths(categoryId)) {
    revalidatePath(path);
  }
}
