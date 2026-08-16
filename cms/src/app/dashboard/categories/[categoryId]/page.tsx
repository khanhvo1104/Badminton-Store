import { notFound, redirect } from "next/navigation";

import { categoryEditPath } from "@/features/categories/constants";
import { isValidUuid } from "@/features/categories/validation";

type CategoryIdPageProps = {
  params: Promise<{ categoryId: string }>;
};

export default async function CategoryIdPage({ params }: CategoryIdPageProps) {
  const { categoryId } = await params;
  if (!isValidUuid(categoryId)) {
    notFound();
  }
  redirect(categoryEditPath(categoryId));
}
