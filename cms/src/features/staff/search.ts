import { STAFF_SEARCH_MAX_LENGTH } from "@/features/staff/constants";

export function normalizeStaffSearch(value: string): string {
  return value.trim().slice(0, STAFF_SEARCH_MAX_LENGTH);
}
