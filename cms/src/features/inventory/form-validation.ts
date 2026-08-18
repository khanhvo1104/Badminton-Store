import {
  INVENTORY_BACKORDER_INVALID_MESSAGE,
  INVENTORY_FIX_FIELDS_MESSAGE,
  INVENTORY_NOTE_INVALID_MESSAGE,
  INVENTORY_NOTE_MAX_LENGTH,
  INVENTORY_OPERATION_INVALID_MESSAGE,
  INVENTORY_POSITIVE_QUANTITY_MESSAGE,
  INVENTORY_QUANTITY_INVALID_MESSAGE,
  INVENTORY_QUANTITY_REQUIRED_MESSAGE,
  INVENTORY_REASON_INVALID_MESSAGE,
} from "@/features/inventory/constants";
import type {
  InventoryFieldErrors,
  InventoryFormValues,
  ParsedInventoryAdjustment,
} from "@/features/inventory/types";
import {
  isInventoryOperation,
  isInventoryReason,
  normalizeInventoryNote,
  normalizeInventoryReason,
  parseExactInteger,
} from "@/features/inventory/validation";

export function readInventoryFormValues(
  formData: FormData,
): InventoryFormValues {
  return {
    operation: readTrimmed(formData, "operation"),
    quantity: readTrimmed(formData, "quantity"),
    allowBackorder: readTrimmed(formData, "allow_backorder"),
    reason: readTrimmed(formData, "reason"),
    note: readString(formData, "note"),
  };
}

export function preserveSafeInventoryValues(
  values: InventoryFormValues,
): InventoryFormValues {
  return {
    operation: values.operation.trim(),
    quantity: values.quantity.trim(),
    allowBackorder: values.allowBackorder.trim(),
    reason: normalizeInventoryReason(values.reason),
    note: values.note.trim(),
  };
}

export function parseInventoryFormInput(formData: FormData):
  | {
      ok: true;
      data: ParsedInventoryAdjustment;
      values: InventoryFormValues;
    }
  | {
      ok: false;
      message: string;
      fieldErrors: InventoryFieldErrors;
      values: InventoryFormValues;
    } {
  const values = preserveSafeInventoryValues(readInventoryFormValues(formData));
  const fieldErrors: InventoryFieldErrors = {};

  if (!isInventoryOperation(values.operation)) {
    fieldErrors.operation = INVENTORY_OPERATION_INVALID_MESSAGE;
  }

  const reason = normalizeInventoryReason(values.reason);
  if (!isInventoryReason(reason)) {
    fieldErrors.reason = INVENTORY_REASON_INVALID_MESSAGE;
  }

  const noteRaw = values.note.trim();
  if (noteRaw.length > INVENTORY_NOTE_MAX_LENGTH) {
    fieldErrors.note = INVENTORY_NOTE_INVALID_MESSAGE;
  }

  let quantity: number | null = null;
  let allowBackorder: boolean | null = null;

  if (values.operation === "set_allow_backorder") {
    if (values.quantity !== "") {
      fieldErrors.quantity = INVENTORY_QUANTITY_INVALID_MESSAGE;
    }
    if (values.allowBackorder !== "true" && values.allowBackorder !== "false") {
      fieldErrors.allowBackorder = INVENTORY_BACKORDER_INVALID_MESSAGE;
    } else {
      allowBackorder = values.allowBackorder === "true";
    }
  } else if (isInventoryOperation(values.operation)) {
    if (values.quantity === "") {
      fieldErrors.quantity = INVENTORY_QUANTITY_REQUIRED_MESSAGE;
    } else {
      const parsed = parseExactInteger(values.quantity);
      if (parsed === null) {
        fieldErrors.quantity = INVENTORY_QUANTITY_INVALID_MESSAGE;
      } else if (
        (values.operation === "add_stock" ||
          values.operation === "remove_stock") &&
        parsed < 1
      ) {
        fieldErrors.quantity = INVENTORY_POSITIVE_QUANTITY_MESSAGE;
      } else {
        quantity = parsed;
      }
    }
  }

  if (Object.keys(fieldErrors).length > 0) {
    return {
      ok: false,
      message: INVENTORY_FIX_FIELDS_MESSAGE,
      fieldErrors,
      values,
    };
  }

  return {
    ok: true,
    data: {
      operation: values.operation as ParsedInventoryAdjustment["operation"],
      quantity,
      allowBackorder,
      reason: reason as ParsedInventoryAdjustment["reason"],
      note: normalizeInventoryNote(noteRaw),
    },
    values,
  };
}

function readTrimmed(formData: FormData, key: string): string {
  const value = formData.get(key);
  return typeof value === "string" ? value.trim() : "";
}

function readString(formData: FormData, key: string): string {
  const value = formData.get(key);
  return typeof value === "string" ? value : "";
}
