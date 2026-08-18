"use server";

import { redirect } from "next/navigation";

import {
  denialState,
  errorState,
  requireInventoryActionAuth,
} from "@/features/inventory/action-utils";
import {
  ADJUST_CMS_INVENTORY_RPC,
  INVENTORY_GENERIC_FAILURE_MESSAGE,
  INVENTORY_NOT_FOUND_MESSAGE,
  INVENTORY_SUCCESS_ADJUSTED,
  inventoryAdjustmentPath,
} from "@/features/inventory/constants";
import {
  isNotFoundError,
  toInventoryMutationFailureMessage,
} from "@/features/inventory/errors";
import {
  parseInventoryFormInput,
  preserveSafeInventoryValues,
  readInventoryFormValues,
} from "@/features/inventory/form-validation";
import { readAdjustedInventoryVariantId } from "@/features/inventory/mappers";
import { revalidateInventoryPaths } from "@/features/inventory/revalidate";
import type { InventoryFormState } from "@/features/inventory/types";
import { isValidUuid } from "@/features/products/validation";

export async function adjustInventory(
  variantId: string,
  _previousState: InventoryFormState,
  formData: FormData,
): Promise<InventoryFormState> {
  const auth = await requireInventoryActionAuth();
  if (!auth.ok) {
    return denialState(
      preserveSafeInventoryValues(readInventoryFormValues(formData)),
    );
  }

  if (!isValidUuid(variantId)) {
    return errorState(
      preserveSafeInventoryValues(readInventoryFormValues(formData)),
      INVENTORY_NOT_FOUND_MESSAGE,
    );
  }

  const parsed = parseInventoryFormInput(formData);
  if (!parsed.ok) {
    return errorState(parsed.values, parsed.message, parsed.fieldErrors);
  }

  try {
    const { data, error } = await auth.supabase.rpc(ADJUST_CMS_INVENTORY_RPC, {
      p_variant_id: variantId,
      p_operation: parsed.data.operation,
      p_quantity: parsed.data.quantity,
      p_allow_backorder: parsed.data.allowBackorder,
      p_reason: parsed.data.reason,
      p_note: parsed.data.note,
    });
    if (error) {
      if (isNotFoundError(error)) {
        return errorState(parsed.values, INVENTORY_NOT_FOUND_MESSAGE);
      }
      return errorState(
        parsed.values,
        toInventoryMutationFailureMessage(error),
      );
    }
    if (!readAdjustedInventoryVariantId(data, variantId)) {
      return errorState(parsed.values, INVENTORY_GENERIC_FAILURE_MESSAGE);
    }
  } catch {
    return errorState(parsed.values, INVENTORY_GENERIC_FAILURE_MESSAGE);
  }

  revalidateInventoryPaths(variantId);
  redirect(
    `${inventoryAdjustmentPath(variantId)}?success=${INVENTORY_SUCCESS_ADJUSTED}`,
  );
}
