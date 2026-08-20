"use server";

import { redirect } from "next/navigation";

import {
  denialState,
  errorState,
  requireOrdersActionAuth,
} from "@/features/orders/action-utils";
import {
  ORDERS_GENERIC_FAILURE_MESSAGE,
  ORDERS_NOT_FOUND_MESSAGE,
  ORDERS_SUCCESS_TRANSITIONED,
  ORDER_DETAIL_COLUMNS,
  orderDetailPath,
  TRANSITION_CMS_ORDER_STATUS_RPC,
} from "@/features/orders/constants";
import {
  isNotFoundError,
  toOrderMutationFailureMessage,
} from "@/features/orders/errors";
import {
  parseOrderTransitionFormInput,
  preserveSafeOrderTransitionValues,
  readOrderTransitionFormValues,
} from "@/features/orders/form-validation";
import {
  mapOrderDetailRow,
  readTransitionedOrderId,
} from "@/features/orders/mappers";
import { revalidateOrderPaths } from "@/features/orders/revalidate";
import type { OrderTransitionFormState } from "@/features/orders/types";
import { isValidUuid } from "@/features/products/validation";

export async function transitionOrderStatus(
  orderId: string,
  _previousState: OrderTransitionFormState,
  formData: FormData,
): Promise<OrderTransitionFormState> {
  const auth = await requireOrdersActionAuth();
  if (!auth.ok) {
    return denialState(
      preserveSafeOrderTransitionValues(
        readOrderTransitionFormValues(formData),
      ),
    );
  }

  if (!isValidUuid(orderId)) {
    return errorState(
      preserveSafeOrderTransitionValues(
        readOrderTransitionFormValues(formData),
      ),
      ORDERS_NOT_FOUND_MESSAGE,
    );
  }

  try {
    const currentResult = await auth.supabase
      .from("orders")
      .select(ORDER_DETAIL_COLUMNS)
      .eq("id", orderId)
      .maybeSingle();

    if (currentResult.error) {
      return errorState(
        preserveSafeOrderTransitionValues(
          readOrderTransitionFormValues(formData),
        ),
        toOrderMutationFailureMessage(currentResult.error),
      );
    }
    if (!currentResult.data) {
      return errorState(
        preserveSafeOrderTransitionValues(
          readOrderTransitionFormValues(formData),
        ),
        ORDERS_NOT_FOUND_MESSAGE,
      );
    }

    const current = mapOrderDetailRow(currentResult.data);
    if (!current) {
      return errorState(
        preserveSafeOrderTransitionValues(
          readOrderTransitionFormValues(formData),
        ),
        ORDERS_GENERIC_FAILURE_MESSAGE,
      );
    }

    const parsed = parseOrderTransitionFormInput(formData, current.status);
    if (!parsed.ok) {
      return errorState(parsed.values, parsed.message, parsed.fieldErrors);
    }

    const { data, error } = await auth.supabase.rpc(
      TRANSITION_CMS_ORDER_STATUS_RPC,
      {
        p_order_id: orderId,
        p_to_status: parsed.data.toStatus,
        p_note: parsed.data.note,
      },
    );
    if (error) {
      if (isNotFoundError(error)) {
        return errorState(parsed.values, ORDERS_NOT_FOUND_MESSAGE);
      }
      return errorState(parsed.values, toOrderMutationFailureMessage(error));
    }
    if (!readTransitionedOrderId(data, orderId)) {
      return errorState(parsed.values, ORDERS_GENERIC_FAILURE_MESSAGE);
    }
  } catch {
    return errorState(
      preserveSafeOrderTransitionValues(
        readOrderTransitionFormValues(formData),
      ),
      ORDERS_GENERIC_FAILURE_MESSAGE,
    );
  }

  revalidateOrderPaths(orderId);
  redirect(
    `${orderDetailPath(orderId)}?success=${ORDERS_SUCCESS_TRANSITIONED}`,
  );
}
