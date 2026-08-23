"use server";

import { redirect } from "next/navigation";

import {
  readConfirmation,
  requireStaffAdminActionAuth,
} from "@/features/staff/action-utils";
import {
  STAFF_CONFIRM_REQUIRED_MESSAGE,
  STAFF_GENERIC_FAILURE_MESSAGE,
  STAFF_LIST_PATH,
  STAFF_NOT_FOUND_MESSAGE,
  STAFF_SUCCESS_ACTIVATED,
  STAFF_SUCCESS_DEACTIVATED,
  STAFF_SUCCESS_DEMOTED,
  STAFF_SUCCESS_PROMOTED,
  UPDATE_CMS_STAFF_RPC,
} from "@/features/staff/constants";
import { toStaffMutationFailureMessage } from "@/features/staff/errors";
import { readUpdatedStaffProfileId } from "@/features/staff/mappers";
import { revalidateStaffPaths } from "@/features/staff/revalidate";
import type { StaffMutationFormState, StaffRole } from "@/features/staff/types";
import { isValidUuid } from "@/features/products/validation";

export async function updateStaffMember(
  profileId: string,
  _previousState: StaffMutationFormState,
  formData: FormData,
): Promise<StaffMutationFormState> {
  const confirmed = readConfirmation(formData, "confirmed");
  if (!confirmed) {
    return {
      status: "error",
      message: STAFF_CONFIRM_REQUIRED_MESSAGE,
      fieldErrors: { confirmed: STAFF_CONFIRM_REQUIRED_MESSAGE },
      values: { confirmed: false },
    };
  }

  if (!isValidUuid(profileId)) {
    return {
      status: "error",
      message: STAFF_NOT_FOUND_MESSAGE,
      fieldErrors: {},
      values: { confirmed: true },
    };
  }

  const auth = await requireStaffAdminActionAuth();
  if (!auth.ok) {
    return auth.state as StaffMutationFormState;
  }

  const nextRole = readOptionalRole(formData.get("role"));
  const nextActive = readOptionalActive(formData.get("is_active"));

  if (nextRole === null && nextActive === null) {
    return {
      status: "error",
      message: STAFF_GENERIC_FAILURE_MESSAGE,
      fieldErrors: {},
      values: { confirmed: true },
    };
  }

  try {
    const rpcArgs: Record<string, unknown> = { p_target_id: profileId };
    if (nextRole !== null) {
      rpcArgs.p_role = nextRole;
    }
    if (nextActive !== null) {
      rpcArgs.p_is_active = nextActive;
    }

    const { data, error } = await auth.supabase.rpc(
      UPDATE_CMS_STAFF_RPC,
      rpcArgs,
    );

    if (error) {
      return {
        status: "error",
        message: toStaffMutationFailureMessage(error),
        fieldErrors: {},
        values: { confirmed: true },
      };
    }

    if (!readUpdatedStaffProfileId(data, profileId)) {
      return {
        status: "error",
        message: STAFF_GENERIC_FAILURE_MESSAGE,
        fieldErrors: {},
        values: { confirmed: true },
      };
    }
  } catch {
    return {
      status: "error",
      message: STAFF_GENERIC_FAILURE_MESSAGE,
      fieldErrors: {},
      values: { confirmed: true },
    };
  }

  revalidateStaffPaths();
  redirect(
    `${STAFF_LIST_PATH}?success=${resolveSuccessToken(nextRole, nextActive)}`,
  );
}

export async function setStaffActive(
  profileId: string,
  _previousState: StaffMutationFormState,
  formData: FormData,
): Promise<StaffMutationFormState> {
  return updateStaffMember(profileId, _previousState, formData);
}

export async function setStaffRole(
  profileId: string,
  _previousState: StaffMutationFormState,
  formData: FormData,
): Promise<StaffMutationFormState> {
  return updateStaffMember(profileId, _previousState, formData);
}

function readOptionalRole(
  value: FormDataEntryValue | null,
): StaffRole | null | undefined {
  if (value === null || value === "") {
    return null;
  }
  if (value === "staff" || value === "admin") {
    return value;
  }
  return undefined;
}

function readOptionalActive(
  value: FormDataEntryValue | null,
): boolean | null | undefined {
  if (value === null || value === "") {
    return null;
  }
  if (typeof value !== "string") {
    return undefined;
  }
  const normalized = value.trim().toLowerCase();
  if (["on", "true", "1", "yes"].includes(normalized)) {
    return true;
  }
  if (["off", "false", "0", "no"].includes(normalized)) {
    return false;
  }
  return undefined;
}

function resolveSuccessToken(
  nextRole: StaffRole | null | undefined,
  nextActive: boolean | null | undefined,
): string {
  if (nextActive === true) {
    return STAFF_SUCCESS_ACTIVATED;
  }
  if (nextActive === false) {
    return STAFF_SUCCESS_DEACTIVATED;
  }
  if (nextRole === "admin") {
    return STAFF_SUCCESS_PROMOTED;
  }
  if (nextRole === "staff") {
    return STAFF_SUCCESS_DEMOTED;
  }
  return STAFF_SUCCESS_ACTIVATED;
}
