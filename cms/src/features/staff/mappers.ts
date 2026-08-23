import type {
  CmsStaffRpcRow,
  StaffListItem,
  StaffRole,
} from "@/features/staff/types";

export function mapCmsStaffRpcRow(row: unknown): CmsStaffRpcRow | null {
  if (!isRecord(row)) {
    return null;
  }

  return {
    profile_id: readNullableString(row.profile_id),
    full_name: readNullableString(row.full_name),
    email: readNullableString(row.email),
    role: readNullableString(row.role),
    is_active: typeof row.is_active === "boolean" ? row.is_active : null,
    created_at: readNullableString(row.created_at),
    filtered_count:
      typeof row.filtered_count === "number" ? row.filtered_count : null,
  };
}

export function mapStaffListItem(
  row: CmsStaffRpcRow & { profile_id: string; email: string },
): StaffListItem | null {
  if (row.role !== "staff" && row.role !== "admin") {
    return null;
  }
  if (
    typeof row.is_active !== "boolean" ||
    typeof row.created_at !== "string"
  ) {
    return null;
  }

  return {
    profileId: row.profile_id,
    fullName: row.full_name,
    email: row.email,
    role: row.role as StaffRole,
    isActive: row.is_active,
    createdAt: row.created_at,
  };
}

export function readUpdatedStaffProfileId(
  data: unknown,
  expectedId: string,
): string | null {
  if (typeof data === "string" && data === expectedId) {
    return data;
  }
  return null;
}

export function getStaffDisplayName(item: StaffListItem): string {
  const trimmed = item.fullName?.trim();
  if (trimmed) {
    return trimmed;
  }
  return item.email;
}

function readNullableString(value: unknown): string | null {
  return typeof value === "string" ? value : null;
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null;
}
