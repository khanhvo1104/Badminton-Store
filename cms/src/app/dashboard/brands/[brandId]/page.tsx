import { notFound, redirect } from "next/navigation";

import { brandEditPath } from "@/features/brands/constants";
import { isValidUuid } from "@/features/brands/validation";

type BrandIdPageProps = {
  params: Promise<{ brandId: string }>;
};

export default async function BrandIdPage({ params }: BrandIdPageProps) {
  const { brandId } = await params;
  if (!isValidUuid(brandId)) {
    notFound();
  }
  redirect(brandEditPath(brandId));
}
