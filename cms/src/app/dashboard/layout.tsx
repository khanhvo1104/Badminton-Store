import type { ReactNode } from "react";
import { redirect } from "next/navigation";

import { DashboardShell } from "@/components/layout/dashboard-shell";
import {
  type AuthorizationSupabaseClient,
  authorizeCmsRequest,
  CMS_LOGIN_PATH,
  CMS_UNAUTHORIZED_PATH,
} from "@/lib/auth/authorization";
import { createSupabaseServerClient } from "@/lib/supabase/server";

export const dynamic = "force-dynamic";

type DashboardLayoutProps = {
  children: ReactNode;
};

export default async function DashboardLayout({
  children,
}: DashboardLayoutProps) {
  const supabase = await createSupabaseServerClient();
  const authorization = await authorizeCmsRequest(
    supabase as unknown as AuthorizationSupabaseClient,
  );

  if (authorization.kind === "anonymous") {
    redirect(CMS_LOGIN_PATH);
  }

  if (authorization.kind === "unauthorized") {
    redirect(CMS_UNAUTHORIZED_PATH);
  }

  return (
    <DashboardShell
      profile={{
        fullName: authorization.profile.fullName,
        role: authorization.profile.role,
      }}
    >
      {children}
    </DashboardShell>
  );
}
