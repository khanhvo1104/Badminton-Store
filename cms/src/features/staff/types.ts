import {
  STAFF_ACTIVE_FILTERS,
  STAFF_ROLE_FILTERS,
  STAFF_ROLES,
  STAFF_SORTS,
} from "@/features/staff/constants";
import type { StaffPagination } from "@/features/staff/validation";

export type StaffRole = (typeof STAFF_ROLES)[number];
export type StaffRoleFilter = (typeof STAFF_ROLE_FILTERS)[number];
export type StaffActiveFilter = (typeof STAFF_ACTIVE_FILTERS)[number];
export type StaffSort = (typeof STAFF_SORTS)[number];

export type StaffListItem = {
  profileId: string;
  fullName: string | null;
  email: string;
  role: StaffRole;
  isActive: boolean;
  createdAt: string;
};

export type StaffExplorerQuery = {
  search: string;
  role: StaffRoleFilter;
  active: StaffActiveFilter;
  sort: StaffSort;
  pagination: StaffPagination;
};

export type StaffListResult = {
  items: StaffListItem[];
  totalCount: number;
  pagination: StaffPagination;
  totalPages: number;
  query: StaffExplorerQuery;
  hasActiveFilters: boolean;
};

export type StaffExplorerLoadResult =
  | { ok: true; result: StaffListResult }
  | { ok: false; message: string };

export type StaffMutationFormValues = {
  confirmed: boolean;
};

export type StaffInviteFormValues = {
  email: string;
  fullName: string;
  role: StaffRole;
  confirmed: boolean;
};

export type StaffMutationFormState = {
  status: "idle" | "error";
  message: string;
  fieldErrors: Partial<Record<"confirmed", string>>;
  values: StaffMutationFormValues;
};

export type StaffInviteFormState = {
  status: "idle" | "error" | "success";
  message: string;
  fieldErrors: Partial<
    Record<"email" | "fullName" | "role" | "confirmed", string>
  >;
  values: StaffInviteFormValues;
};

export type CmsStaffRpcRow = {
  profile_id: string | null;
  full_name: string | null;
  email: string | null;
  role: string | null;
  is_active: boolean | null;
  created_at: string | null;
  filtered_count: number | null;
};
