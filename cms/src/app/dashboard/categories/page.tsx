import { CatalogPlaceholderPage } from "@/features/dashboard/components/catalog-placeholder-page";

export default function CategoriesPlaceholderPage() {
  return (
    <CatalogPlaceholderPage
      eyebrow="Categories"
      title="Categories"
      description="Category listing and editing are not available in this shell task."
      emptyTitle="Category management comes next"
      emptyDescription="This protected placeholder keeps navigation ready. Category CRUD arrives in a later catalog task and will not query data from this page yet."
    />
  );
}
