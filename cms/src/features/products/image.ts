import { PRODUCT_IMAGES_BUCKET } from "@/features/products/constants";

export function toProductImageObjectPath(storedPath: string): string {
  const normalized = storedPath.replace(/^\/+/, "");
  const prefix = `${PRODUCT_IMAGES_BUCKET}/`;
  if (normalized.startsWith(prefix)) {
    return normalized.slice(prefix.length);
  }
  return normalized;
}

export function buildProductImagePublicUrl(
  supabaseUrl: string,
  storedPath: string | null | undefined,
): string | null {
  if (!storedPath || !storedPath.trim() || !supabaseUrl.trim()) {
    return null;
  }

  const objectPath = toProductImageObjectPath(storedPath);
  if (!objectPath || objectPath.includes("..") || objectPath.startsWith("/")) {
    return null;
  }

  const base = supabaseUrl.replace(/\/+$/, "");
  return `${base}/storage/v1/object/public/${PRODUCT_IMAGES_BUCKET}/${objectPath}`;
}
