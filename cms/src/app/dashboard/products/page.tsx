import { CatalogPlaceholderPage } from "@/features/dashboard/components/catalog-placeholder-page";

export default function ProductsPlaceholderPage() {
  return (
    <CatalogPlaceholderPage
      eyebrow="Products"
      title="Products"
      description="Product explorer and editor workflows are not available in this shell task."
      emptyTitle="Product management comes next"
      emptyDescription="This protected placeholder keeps navigation ready. Product listing and editing arrive in later catalog tasks and will not query data from this page yet."
    />
  );
}
