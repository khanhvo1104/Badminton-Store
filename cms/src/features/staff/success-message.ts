import {
  STAFF_SUCCESS_ACTIVATED,
  STAFF_SUCCESS_DEACTIVATED,
  STAFF_SUCCESS_DEMOTED,
  STAFF_SUCCESS_INVITED,
  STAFF_SUCCESS_PROMOTED,
} from "@/features/staff/constants";

export function readStaffSuccessMessage(
  value: string | string[] | undefined,
): string | null {
  if (typeof value !== "string") {
    return null;
  }

  switch (value) {
    case STAFF_SUCCESS_INVITED:
      return "Invitation sent. The new staff member can set a password from the email link.";
    case STAFF_SUCCESS_ACTIVATED:
      return "Staff member activated.";
    case STAFF_SUCCESS_DEACTIVATED:
      return "Staff member deactivated.";
    case STAFF_SUCCESS_PROMOTED:
      return "Staff member promoted to admin.";
    case STAFF_SUCCESS_DEMOTED:
      return "Admin demoted to staff.";
    default:
      return null;
  }
}
