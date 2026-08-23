import { revalidatePath } from "next/cache";

import { STAFF_LIST_PATH } from "@/features/staff/constants";

export function revalidateStaffPaths(): void {
  revalidatePath(STAFF_LIST_PATH);
}
