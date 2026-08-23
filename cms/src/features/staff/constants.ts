export const STAFF_LIST_PATH = "/dashboard/staff";

export const LIST_CMS_STAFF_RPC = "list_cms_staff";
export const UPDATE_CMS_STAFF_RPC = "update_cms_staff";
export const INVITE_CMS_STAFF_FUNCTION = "invite-cms-staff";

export const STAFF_PAGE_SIZE_DEFAULT = 20;
export const STAFF_PAGE_SIZE_MAX = 50;
export const STAFF_SEARCH_MAX_LENGTH = 80;
export const STAFF_FULL_NAME_MAX_LENGTH = 120;

export const STAFF_ROLES = ["staff", "admin"] as const;
export const STAFF_ROLE_FILTERS = ["all", ...STAFF_ROLES] as const;
export const STAFF_ACTIVE_FILTERS = ["all", "active", "inactive"] as const;

export const STAFF_SORTS = [
  "name_asc",
  "name_desc",
  "created_desc",
  "created_asc",
  "role_asc",
] as const;

export const STAFF_AUTH_DENIED_MESSAGE =
  "Staff management is available only to active admin accounts.";
export const STAFF_LOAD_FAILURE_MESSAGE =
  "We couldn't load staff members right now. Try again.";
export const STAFF_GENERIC_FAILURE_MESSAGE =
  "We couldn't save that staff change. Try again.";
export const STAFF_MUTATION_AUTH_DENIED_MESSAGE =
  "You don't have permission to change staff members.";
export const STAFF_NOT_FOUND_MESSAGE = "That staff member could not be found.";
export const STAFF_SELF_CHANGE_DENIED_MESSAGE =
  "You can't deactivate or demote your own admin account.";
export const STAFF_LAST_ADMIN_DENIED_MESSAGE =
  "At least one active admin must remain.";
export const STAFF_CONFIRM_REQUIRED_MESSAGE =
  "Confirm this staff change before continuing.";
export const STAFF_INVITE_CONFIRM_REQUIRED_MESSAGE =
  "Confirm this invitation before sending it.";

export const STAFF_SUCCESS_ACTIVATED = "staff-activated";
export const STAFF_SUCCESS_DEACTIVATED = "staff-deactivated";
export const STAFF_SUCCESS_PROMOTED = "staff-promoted";
export const STAFF_SUCCESS_DEMOTED = "staff-demoted";
export const STAFF_SUCCESS_INVITED = "staff-invited";

export const STAFF_INVITE_GENERIC_FAILURE_MESSAGE =
  "We couldn't send that invitation. Try again later.";
export const STAFF_INVITE_RATE_LIMIT_MESSAGE =
  "Email sending is temporarily limited. Wait a few minutes and try again, or ask your operator to review SMTP rate limits.";
export const STAFF_INVITE_DUPLICATE_MESSAGE =
  "That email already belongs to an account. Update the existing staff member instead of sending a new invitation.";
