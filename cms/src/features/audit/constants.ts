export const AUDIT_LIST_PATH = "/dashboard/audit";

export const LIST_CMS_PRIVILEGED_AUDIT_RPC = "list_cms_privileged_audit_events";

export const AUDIT_PAGE_SIZE_DEFAULT = 25;
export const AUDIT_PAGE_SIZE_MAX = 50;

export const AUDIT_ENTITY_TYPES = [
  "all",
  "category",
  "brand",
  "product",
  "variant",
  "inventory",
  "product_media",
  "order",
  "staff",
] as const;

export const AUDIT_ACTIONS = [
  "all",
  "create",
  "update",
  "delete",
  "activate",
  "deactivate",
  "status_change",
  "adjust",
  "set_primary",
  "reorder",
  "status_transition",
  "annotate_transition",
  "invite",
  "promote",
  "demote",
] as const;

export const AUDIT_AUTH_DENIED_MESSAGE =
  "The audit trail is available only to active admin accounts.";
export const AUDIT_LOAD_FAILURE_MESSAGE =
  "We couldn't load audit events right now. Try again.";
export const AUDIT_EMPTY_MESSAGE = "No privileged changes match these filters.";

export const AUDIT_ENTITY_LABELS: Record<
  Exclude<(typeof AUDIT_ENTITY_TYPES)[number], "all">,
  string
> = {
  category: "Category",
  brand: "Brand",
  product: "Product",
  variant: "Variant",
  inventory: "Inventory",
  product_media: "Product media",
  order: "Order",
  staff: "Staff",
};

export const AUDIT_ACTION_LABELS: Record<
  Exclude<(typeof AUDIT_ACTIONS)[number], "all">,
  string
> = {
  create: "Created",
  update: "Updated",
  delete: "Deleted",
  activate: "Activated",
  deactivate: "Deactivated",
  status_change: "Status changed",
  adjust: "Adjusted",
  set_primary: "Primary set",
  reorder: "Reordered",
  status_transition: "Status transition",
  annotate_transition: "Transition note added",
  invite: "Invited",
  promote: "Promoted",
  demote: "Demoted",
};
