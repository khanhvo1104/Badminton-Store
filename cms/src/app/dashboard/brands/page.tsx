import { CatalogPlaceholderPage } from "@/features/dashboard/components/catalog-placeholder-page";

export default function BrandsPlaceholderPage() {
  return (
    <CatalogPlaceholderPage
      eyebrow="Brands"
      title="Brands"
      description="Brand listing and editing are not available in this shell task."
      emptyTitle="Brand management comes next"
      emptyDescription="This protected placeholder keeps navigation ready. Brand CRUD arrives in a later catalog task and will not query data from this page yet."
    />
  );
}
