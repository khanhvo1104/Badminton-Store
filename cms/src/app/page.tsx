import { redirect } from "next/navigation";

import { CMS_DASHBOARD_PATH, CMS_LOGIN_PATH } from "@/lib/auth/authorization";
import { createSupabaseServerClient } from "@/lib/supabase/server";

export const dynamic = "force-dynamic";

export default async function Home() {
  const supabase = await createSupabaseServerClient();
  const { data, error } = await supabase.auth.getClaims();
  const subject = data?.claims?.sub;

  if (!error && typeof subject === "string" && subject.trim()) {
    redirect(CMS_DASHBOARD_PATH);
  }

  redirect(CMS_LOGIN_PATH);
}
