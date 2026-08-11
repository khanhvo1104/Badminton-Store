"use server";

import { redirect } from "next/navigation";

import { CMS_LOGIN_PATH, getVerifiedSubject } from "@/lib/auth/authorization";
import { createSupabaseServerClient } from "@/lib/supabase/server";

export async function logout() {
  const supabase = await createSupabaseServerClient({ canSetCookies: true });
  const subject = await getVerifiedSubject(supabase);

  if (subject) {
    await supabase.auth.signOut();
  }

  redirect(CMS_LOGIN_PATH);
}
