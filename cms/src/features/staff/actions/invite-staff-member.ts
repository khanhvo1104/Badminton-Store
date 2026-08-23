"use server";

import { redirect } from "next/navigation";

import {
  getStaffActionAccessToken,
  readConfirmation,
  requireStaffAdminActionAuth,
} from "@/features/staff/action-utils";
import {
  INVITE_CMS_STAFF_FUNCTION,
  STAFF_FULL_NAME_MAX_LENGTH,
  STAFF_GENERIC_FAILURE_MESSAGE,
  STAFF_INVITE_CONFIRM_REQUIRED_MESSAGE,
  STAFF_LIST_PATH,
  STAFF_SUCCESS_INVITED,
} from "@/features/staff/constants";
import { mapInviteFunctionError } from "@/features/staff/errors";
import { revalidateStaffPaths } from "@/features/staff/revalidate";
import type { StaffInviteFormState } from "@/features/staff/types";
import { getPublicEnvironment } from "@/lib/env/public-env";
import { isSyntacticallyValidEmail } from "@/lib/auth/password-recovery";

export async function inviteStaffMember(
  _previousState: StaffInviteFormState,
  formData: FormData,
): Promise<StaffInviteFormState> {
  const values = readInviteFormValues(formData);

  if (!values.confirmed) {
    return {
      status: "error",
      message: STAFF_INVITE_CONFIRM_REQUIRED_MESSAGE,
      fieldErrors: { confirmed: STAFF_INVITE_CONFIRM_REQUIRED_MESSAGE },
      values,
    };
  }

  const fieldErrors = validateInviteValues(formData, values);
  if (Object.keys(fieldErrors).length > 0) {
    return {
      status: "error",
      message: STAFF_GENERIC_FAILURE_MESSAGE,
      fieldErrors,
      values,
    };
  }

  const auth = await requireStaffAdminActionAuth();
  if (!auth.ok) {
    return auth.state as StaffInviteFormState;
  }

  const accessToken = await getStaffActionAccessToken(auth.supabase);
  if (!accessToken) {
    return {
      status: "error",
      message: STAFF_GENERIC_FAILURE_MESSAGE,
      fieldErrors: {},
      values,
    };
  }

  try {
    const environment = getPublicEnvironment();
    const inviteUrl = new URL(
      `/functions/v1/${INVITE_CMS_STAFF_FUNCTION}`,
      environment.supabaseUrl,
    );

    const response = await fetch(inviteUrl, {
      method: "POST",
      headers: {
        Authorization: `Bearer ${accessToken}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        email: values.email,
        role: values.role,
        fullName: values.fullName || null,
      }),
      cache: "no-store",
    });

    let body: unknown = null;
    try {
      body = await response.json();
    } catch {
      body = null;
    }

    if (!response.ok) {
      return {
        status: "error",
        message: mapInviteFunctionError(response.status, body),
        fieldErrors: {},
        values,
      };
    }

    if (!isRecord(body) || body.ok !== true) {
      return {
        status: "error",
        message: STAFF_GENERIC_FAILURE_MESSAGE,
        fieldErrors: {},
        values,
      };
    }
  } catch {
    return {
      status: "error",
      message: STAFF_GENERIC_FAILURE_MESSAGE,
      fieldErrors: {},
      values,
    };
  }

  revalidateStaffPaths();
  redirect(`${STAFF_LIST_PATH}?success=${STAFF_SUCCESS_INVITED}`);
}

function readInviteFormValues(
  formData: FormData,
): StaffInviteFormState["values"] {
  const role = readRole(formData.get("role"));
  return {
    email: readString(formData, "email").toLowerCase(),
    fullName: readString(formData, "fullName"),
    role: role ?? "staff",
    confirmed: readConfirmation(formData, "confirmed"),
  };
}

function validateInviteValues(
  formData: FormData,
  values: StaffInviteFormState["values"],
) {
  const fieldErrors: StaffInviteFormState["fieldErrors"] = {};

  if (!isSyntacticallyValidEmail(values.email)) {
    fieldErrors.email = "Enter a valid email address.";
  }

  if (values.fullName.length > STAFF_FULL_NAME_MAX_LENGTH) {
    fieldErrors.fullName = "Full name must be 120 characters or fewer.";
  }

  if (!readRole(formData.get("role"))) {
    fieldErrors.role = "Choose staff or admin.";
  }

  return fieldErrors;
}

function readString(formData: FormData, key: string): string {
  const value = formData.get(key);
  return typeof value === "string" ? value.trim() : "";
}

function readRole(value: FormDataEntryValue | null): "staff" | "admin" | null {
  if (value === "staff" || value === "admin") {
    return value;
  }
  return null;
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null;
}
