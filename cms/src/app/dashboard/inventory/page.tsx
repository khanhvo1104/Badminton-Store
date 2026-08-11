import { CatalogPlaceholderPage } from "@/features/dashboard/components/catalog-placeholder-page";

export default function InventoryPlaceholderPage() {
  return (
    <CatalogPlaceholderPage
      eyebrow="Inventory"
      title="Inventory"
      description="Inventory adjustments are not available in this shell task."
      emptyTitle="Inventory tools come next"
      emptyDescription="This protected placeholder keeps navigation ready. Stock adjustments arrive in a later catalog task and will not query or mutate inventory from this page yet."
    />
  );
}
