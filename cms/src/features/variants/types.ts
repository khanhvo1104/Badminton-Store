import type {
  VARIANT_BARCODE_MODES,
  VARIANT_COST_MODES,
} from "@/features/variants/constants";
import type { VariantAttributesJson } from "@/features/variants/attributes";

export type VariantCostMode = (typeof VARIANT_COST_MODES)[number];
export type VariantBarcodeMode = (typeof VARIANT_BARCODE_MODES)[number];

export type VariantListItem = {
  id: string;
  productId: string;
  sku: string;
  name: string | null;
  statusLabel: string;
  defaultLabel: string;
  isDefault: boolean;
  isActive: boolean;
  attributesLabel: string;
  price: string;
  priceLabel: string;
  compareAtPrice: string | null;
  compareAtPriceLabel: string;
  costPrice: string | null;
  costPriceLabel: string;
  unit: string;
  sortOrder: number;
  colorName: string | null;
  colorHex: string | null;
  racketWeightClass: string | null;
  gripSize: string | null;
  shoeSize: string | null;
  clothingSize: string | null;
  attributes: VariantAttributesJson;
};

export type VariantEditorData = {
  productId: string;
  productName: string;
  variants: VariantListItem[];
  isFirstVariant: boolean;
};

export type VariantFormValues = {
  sku: string;
  name: string;
  colorName: string;
  colorHex: string;
  racketWeightClass: string;
  gripSize: string;
  shoeSize: string;
  clothingSize: string;
  unit: string;
  price: string;
  compareAtPrice: string;
  costPrice: string;
  barcode: string;
  barcodeClear: boolean;
  attributes: string;
  isDefault: string;
  isActive: string;
  sortOrder: string;
};

export type VariantFieldErrors = {
  sku?: string;
  name?: string;
  colorName?: string;
  colorHex?: string;
  racketWeightClass?: string;
  gripSize?: string;
  shoeSize?: string;
  clothingSize?: string;
  unit?: string;
  price?: string;
  compareAtPrice?: string;
  costPrice?: string;
  barcode?: string;
  attributes?: string;
  isDefault?: string;
  isActive?: string;
  sortOrder?: string;
  form?: string;
};

export type VariantFormState = {
  status: "idle" | "error" | "success";
  message: string | null;
  fieldErrors: VariantFieldErrors;
  values: VariantFormValues;
};

export type ParsedVariantInput = {
  sku: string;
  name: string | null;
  colorName: string | null;
  colorHex: string | null;
  racketWeightClass: string | null;
  gripSize: string | null;
  shoeSize: string | null;
  clothingSize: string | null;
  unit: string;
  price: string;
  compareAtPrice: string | null;
  costMode: VariantCostMode;
  costPrice: string | null;
  barcodeMode: VariantBarcodeMode;
  barcode: string | null;
  attributes: VariantAttributesJson;
  isDefault: boolean;
  isActive: boolean;
  sortOrder: number;
};

export type VariantMutationArgs = {
  p_product_id: string;
  p_variant_id: string | null;
  p_sku: string;
  p_name: string | null;
  p_color_name: string | null;
  p_color_hex: string | null;
  p_racket_weight_class: string | null;
  p_grip_size: string | null;
  p_shoe_size: string | null;
  p_clothing_size: string | null;
  p_unit: string;
  p_price: string;
  p_compare_at_price: string | null;
  p_cost_mode: VariantCostMode;
  p_cost_price: string | null;
  p_barcode_mode: VariantBarcodeMode;
  p_barcode: string | null;
  p_attributes: VariantAttributesJson;
  p_is_default: boolean;
  p_is_active: boolean;
  p_sort_order: number;
};
