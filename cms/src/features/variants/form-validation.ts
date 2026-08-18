import type {
  ParsedVariantInput,
  VariantFieldErrors,
  VariantFormValues,
  VariantMutationArgs,
} from "@/features/variants/types";
import {
  formatVariantAttributesForForm,
  parseVariantAttributesInput,
} from "@/features/variants/attributes";
import {
  VARIANT_BARCODE_MAX_LENGTH,
  VARIANT_BOOLEAN_INVALID_MESSAGE,
  VARIANT_COLOR_HEX_INVALID_MESSAGE,
  VARIANT_COLOR_HEX_PATTERN,
  VARIANT_COLOR_NAME_MAX_LENGTH,
  VARIANT_COMPARE_RULE_MESSAGE,
  VARIANT_COST_INVALID_MESSAGE,
  VARIANT_DEFAULT_LOCKED_MESSAGE,
  VARIANT_FIX_FIELDS_MESSAGE,
  VARIANT_NAME_MAX_LENGTH,
  VARIANT_PRICE_INVALID_MESSAGE,
  VARIANT_SKU_MAX_LENGTH,
  VARIANT_SORT_ORDER_MAX,
  VARIANT_SORT_ORDER_MIN,
  VARIANT_SPORT_ATTR_MAX_LENGTH,
  VARIANT_UNIT_MAX_LENGTH,
  normalizeOptionalVariantText,
  normalizeVariantSku,
} from "@/features/variants/constants";
import {
  compareVariantMoney,
  parseVariantMoney,
} from "@/features/variants/money";

export function readVariantFormValues(formData: FormData): VariantFormValues {
  return {
    sku: readString(formData, "sku"),
    name: readString(formData, "name"),
    colorName: readString(formData, "color_name"),
    colorHex: readString(formData, "color_hex"),
    racketWeightClass: readString(formData, "racket_weight_class"),
    gripSize: readString(formData, "grip_size"),
    shoeSize: readString(formData, "shoe_size"),
    clothingSize: readString(formData, "clothing_size"),
    unit: readString(formData, "unit"),
    price: readString(formData, "price"),
    compareAtPrice: readString(formData, "compare_at_price"),
    costPrice: readString(formData, "cost_price"),
    barcode: readString(formData, "barcode"),
    barcodeClear: readCheckbox(formData, "barcode_clear"),
    attributes: readString(formData, "attributes"),
    isDefault: readTrimmed(formData, "is_default"),
    isActive: readTrimmed(formData, "is_active"),
    sortOrder: readTrimmed(formData, "sort_order"),
  };
}

export function preserveSafeVariantValues(
  values: VariantFormValues,
): VariantFormValues {
  return {
    ...values,
    sku: normalizeVariantSku(values.sku),
    name: values.name.trim(),
    colorName: values.colorName.trim(),
    colorHex: values.colorHex.trim(),
    racketWeightClass: values.racketWeightClass.trim(),
    gripSize: values.gripSize.trim(),
    shoeSize: values.shoeSize.trim(),
    clothingSize: values.clothingSize.trim(),
    unit: values.unit.trim(),
    price: values.price.trim(),
    compareAtPrice: values.compareAtPrice.trim(),
    costPrice: values.costPrice.trim(),
    barcode: values.barcode.trim(),
    isDefault: values.isDefault.trim(),
    isActive: values.isActive.trim(),
    sortOrder: values.sortOrder.trim(),
  };
}

export function parseVariantFormInput(
  formData: FormData,
  options: {
    mode: "create" | "edit";
    currentIsDefault?: boolean;
  },
):
  | { ok: true; data: ParsedVariantInput; values: VariantFormValues }
  | {
      ok: false;
      fieldErrors: VariantFieldErrors;
      values: VariantFormValues;
      message: string;
    } {
  const values = readVariantFormValues(formData);
  const validated = validateVariantFormValues(values, options);
  if (!validated.ok) {
    return {
      ok: false,
      fieldErrors: validated.fieldErrors,
      values: preserveSafeVariantValues(values),
      message: VARIANT_FIX_FIELDS_MESSAGE,
    };
  }

  return {
    ok: true,
    values: {
      ...preserveSafeVariantValues(values),
      sku: validated.data.sku,
      name: validated.data.name ?? "",
      colorName: validated.data.colorName ?? "",
      colorHex: validated.data.colorHex ?? "",
      racketWeightClass: validated.data.racketWeightClass ?? "",
      gripSize: validated.data.gripSize ?? "",
      shoeSize: validated.data.shoeSize ?? "",
      clothingSize: validated.data.clothingSize ?? "",
      unit: validated.data.unit,
      price: validated.data.price,
      compareAtPrice: validated.data.compareAtPrice ?? "",
      costPrice: validated.data.costPrice ?? "",
      barcode: validated.data.barcode ?? "",
      attributes: formatVariantAttributesForForm(validated.data.attributes),
      isDefault: validated.data.isDefault ? "true" : "false",
      isActive: validated.data.isActive ? "true" : "false",
      sortOrder: String(validated.data.sortOrder),
    },
    data: validated.data,
  };
}

export function validateVariantFormValues(
  values: VariantFormValues,
  options: {
    mode: "create" | "edit";
    currentIsDefault?: boolean;
  },
):
  | { ok: true; data: ParsedVariantInput }
  | { ok: false; fieldErrors: VariantFieldErrors } {
  const fieldErrors: VariantFieldErrors = {};
  const sku = normalizeVariantSku(values.sku);
  const name = blankToNull(values.name.trim());
  const colorName = blankToNull(values.colorName.trim());
  const colorHexRaw = values.colorHex.trim();
  const racketWeightClass = blankToNull(values.racketWeightClass.trim());
  const gripSize = blankToNull(values.gripSize.trim());
  const shoeSize = blankToNull(values.shoeSize.trim());
  const clothingSize = blankToNull(values.clothingSize.trim());
  const unit = values.unit.trim();
  const priceRaw = values.price.trim();
  const compareRaw = values.compareAtPrice.trim();
  const costRaw = values.costPrice.trim();
  const barcodeRaw = normalizeOptionalVariantText(values.barcode);
  const sortRaw = values.sortOrder.trim();

  if (!sku) {
    fieldErrors.sku = "Enter a SKU.";
  } else if (sku.length > VARIANT_SKU_MAX_LENGTH) {
    fieldErrors.sku = `SKU must be at most ${VARIANT_SKU_MAX_LENGTH} characters.`;
  }

  if (name && name.length > VARIANT_NAME_MAX_LENGTH) {
    fieldErrors.name = `Name must be at most ${VARIANT_NAME_MAX_LENGTH} characters.`;
  }
  if (colorName && colorName.length > VARIANT_COLOR_NAME_MAX_LENGTH) {
    fieldErrors.colorName = `Color name must be at most ${VARIANT_COLOR_NAME_MAX_LENGTH} characters.`;
  }

  let colorHex: string | null = null;
  if (colorHexRaw) {
    if (!VARIANT_COLOR_HEX_PATTERN.test(colorHexRaw)) {
      fieldErrors.colorHex = VARIANT_COLOR_HEX_INVALID_MESSAGE;
    } else {
      colorHex = colorHexRaw;
    }
  }

  if (
    racketWeightClass &&
    racketWeightClass.length > VARIANT_SPORT_ATTR_MAX_LENGTH
  ) {
    fieldErrors.racketWeightClass = sportAttrMessage("Racket weight class");
  }
  if (gripSize && gripSize.length > VARIANT_SPORT_ATTR_MAX_LENGTH) {
    fieldErrors.gripSize = sportAttrMessage("Grip size");
  }
  if (shoeSize && shoeSize.length > VARIANT_SPORT_ATTR_MAX_LENGTH) {
    fieldErrors.shoeSize = sportAttrMessage("Shoe size");
  }
  if (clothingSize && clothingSize.length > VARIANT_SPORT_ATTR_MAX_LENGTH) {
    fieldErrors.clothingSize = sportAttrMessage("Clothing size");
  }

  if (!unit) {
    fieldErrors.unit = "Enter a unit.";
  } else if (unit.length > VARIANT_UNIT_MAX_LENGTH) {
    fieldErrors.unit = `Unit must be at most ${VARIANT_UNIT_MAX_LENGTH} characters.`;
  }

  const price = parseVariantMoney(priceRaw);
  if (!priceRaw || price === null) {
    fieldErrors.price = VARIANT_PRICE_INVALID_MESSAGE;
  }

  let compareAtPrice: string | null = null;
  if (compareRaw) {
    const parsedCompare = parseVariantMoney(compareRaw);
    if (parsedCompare === null) {
      fieldErrors.compareAtPrice = VARIANT_PRICE_INVALID_MESSAGE;
    } else {
      compareAtPrice = parsedCompare;
    }
  }

  if (
    price &&
    compareAtPrice &&
    compareVariantMoney(compareAtPrice, price) < 0
  ) {
    fieldErrors.compareAtPrice = VARIANT_COMPARE_RULE_MESSAGE;
  }

  let costMode: ParsedVariantInput["costMode"] = "clear";
  let costPrice: string | null = null;
  if (costRaw) {
    const parsedCost = parseVariantMoney(costRaw);
    if (parsedCost === null) {
      fieldErrors.costPrice = VARIANT_COST_INVALID_MESSAGE;
    } else {
      costMode = "set";
      costPrice = parsedCost;
    }
  }

  let barcodeMode: ParsedVariantInput["barcodeMode"] = "unchanged";
  let barcode: string | null = null;
  if (values.barcodeClear && barcodeRaw) {
    fieldErrors.barcode = "Clear the barcode or enter a new value, not both.";
  } else if (values.barcodeClear) {
    barcodeMode = "clear";
  } else if (barcodeRaw) {
    if (barcodeRaw.length > VARIANT_BARCODE_MAX_LENGTH) {
      fieldErrors.barcode = `Barcode must be at most ${VARIANT_BARCODE_MAX_LENGTH} characters.`;
    } else {
      barcodeMode = "set";
      barcode = barcodeRaw;
    }
  } else if (options.mode === "create") {
    barcodeMode = "unchanged";
  }

  const attributes = parseVariantAttributesInput(values.attributes);
  if (!attributes.ok) {
    fieldErrors.attributes = attributes.message;
  }

  const isDefault = parseRequiredBoolean(values.isDefault);
  if (isDefault === null) {
    fieldErrors.isDefault = VARIANT_BOOLEAN_INVALID_MESSAGE;
  }
  const isActive = parseRequiredBoolean(values.isActive);
  if (isActive === null) {
    fieldErrors.isActive = VARIANT_BOOLEAN_INVALID_MESSAGE;
  }

  if (options.currentIsDefault && isDefault === false) {
    fieldErrors.isDefault = VARIANT_DEFAULT_LOCKED_MESSAGE;
  }

  const sortOrder = parseSortOrder(sortRaw);
  if (sortOrder === null) {
    fieldErrors.sortOrder = `Sort order must be an integer between ${VARIANT_SORT_ORDER_MIN} and ${VARIANT_SORT_ORDER_MAX}.`;
  }

  if (Object.keys(fieldErrors).length > 0 || !attributes.ok) {
    return { ok: false, fieldErrors };
  }
  if (
    !sku ||
    !unit ||
    !price ||
    isDefault === null ||
    isActive === null ||
    sortOrder === null
  ) {
    return { ok: false, fieldErrors };
  }

  return {
    ok: true,
    data: {
      sku,
      name,
      colorName,
      colorHex,
      racketWeightClass,
      gripSize,
      shoeSize,
      clothingSize,
      unit,
      price,
      compareAtPrice,
      costMode,
      costPrice,
      barcodeMode,
      barcode,
      attributes: attributes.value,
      isDefault,
      isActive,
      sortOrder,
    },
  };
}

export function buildVariantMutationArgs(options: {
  productId: string;
  variantId: string | null;
  data: ParsedVariantInput;
}): VariantMutationArgs {
  const { productId, variantId, data } = options;
  return {
    p_product_id: productId,
    p_variant_id: variantId,
    p_sku: data.sku,
    p_name: data.name,
    p_color_name: data.colorName,
    p_color_hex: data.colorHex,
    p_racket_weight_class: data.racketWeightClass,
    p_grip_size: data.gripSize,
    p_shoe_size: data.shoeSize,
    p_clothing_size: data.clothingSize,
    p_unit: data.unit,
    p_price: data.price,
    p_compare_at_price: data.compareAtPrice,
    p_cost_mode: data.costMode,
    p_cost_price: data.costPrice,
    p_barcode_mode: data.barcodeMode,
    p_barcode: data.barcode,
    p_attributes: data.attributes,
    p_is_default: data.isDefault,
    p_is_active: data.isActive,
    p_sort_order: data.sortOrder,
  };
}

function sportAttrMessage(label: string): string {
  return `${label} must be at most ${VARIANT_SPORT_ATTR_MAX_LENGTH} characters.`;
}

function blankToNull(value: string): string | null {
  return value.length > 0 ? value : null;
}

function parseRequiredBoolean(value: string): boolean | null {
  if (value === "true") {
    return true;
  }
  if (value === "false") {
    return false;
  }
  return null;
}

function parseSortOrder(value: string): number | null {
  if (!/^-?\d+$/.test(value)) {
    return null;
  }
  const parsed = Number(value);
  if (!Number.isSafeInteger(parsed)) {
    return null;
  }
  if (parsed < VARIANT_SORT_ORDER_MIN || parsed > VARIANT_SORT_ORDER_MAX) {
    return null;
  }
  return parsed;
}

function readTrimmed(formData: FormData, key: string): string {
  const value = formData.get(key);
  return typeof value === "string" ? value.trim() : "";
}

function readString(formData: FormData, key: string): string {
  const value = formData.get(key);
  return typeof value === "string" ? value : "";
}

function readCheckbox(formData: FormData, key: string): boolean {
  const value = formData.get(key);
  if (typeof value !== "string") {
    return false;
  }
  const normalized = value.trim().toLowerCase();
  return (
    normalized === "on" ||
    normalized === "true" ||
    normalized === "1" ||
    normalized === "yes"
  );
}
