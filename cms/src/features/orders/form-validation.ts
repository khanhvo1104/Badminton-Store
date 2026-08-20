import {
  ORDERS_CONFIRM_REQUIRED_MESSAGE,
  ORDERS_FIX_FIELDS_MESSAGE,
  ORDERS_NOTE_INVALID_MESSAGE,
  ORDERS_NOTE_MAX_LENGTH,
  ORDERS_STATUS_INVALID_MESSAGE,
} from "@/features/orders/constants";
import type {
  OrderStatus,
  OrderTransitionFieldErrors,
  OrderTransitionFormValues,
  ParsedOrderTransition,
} from "@/features/orders/types";
import {
  isAllowedOrderTransition,
  isOrderStatus,
  normalizeOrderNote,
} from "@/features/orders/validation";

export function readOrderTransitionFormValues(
  formData: FormData,
): OrderTransitionFormValues {
  return {
    toStatus: readTrimmed(formData, "to_status"),
    note: readString(formData, "note"),
    confirmed: readTrimmed(formData, "confirmed"),
  };
}

export function preserveSafeOrderTransitionValues(
  values: OrderTransitionFormValues,
): OrderTransitionFormValues {
  return {
    toStatus: values.toStatus.trim(),
    note: values.note.trim(),
    confirmed: values.confirmed.trim(),
  };
}

export function parseOrderTransitionFormInput(
  formData: FormData,
  currentStatus: OrderStatus,
):
  | {
      ok: true;
      data: ParsedOrderTransition;
      values: OrderTransitionFormValues;
    }
  | {
      ok: false;
      message: string;
      fieldErrors: OrderTransitionFieldErrors;
      values: OrderTransitionFormValues;
    } {
  const values = preserveSafeOrderTransitionValues(
    readOrderTransitionFormValues(formData),
  );
  const fieldErrors: OrderTransitionFieldErrors = {};

  if (!isOrderStatus(values.toStatus)) {
    fieldErrors.toStatus = ORDERS_STATUS_INVALID_MESSAGE;
  } else if (!isAllowedOrderTransition(currentStatus, values.toStatus)) {
    fieldErrors.toStatus = ORDERS_STATUS_INVALID_MESSAGE;
  }

  const noteRaw = values.note.trim();
  if (noteRaw.length > ORDERS_NOTE_MAX_LENGTH) {
    fieldErrors.note = ORDERS_NOTE_INVALID_MESSAGE;
  }

  if (values.confirmed !== "1") {
    fieldErrors.confirmed = ORDERS_CONFIRM_REQUIRED_MESSAGE;
  }

  // Never trust form actor / current status / order id fields.
  void formData.get("actor_id");
  void formData.get("current_status");
  void formData.get("order_id");

  if (Object.keys(fieldErrors).length > 0) {
    return {
      ok: false,
      message: ORDERS_FIX_FIELDS_MESSAGE,
      fieldErrors,
      values,
    };
  }

  return {
    ok: true,
    data: {
      toStatus: values.toStatus as OrderStatus,
      note: normalizeOrderNote(noteRaw),
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
