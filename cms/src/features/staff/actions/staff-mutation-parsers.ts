import type { StaffRole } from "@/features/staff/types";

export function readOptionalRole(
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

export function readOptionalActive(
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
