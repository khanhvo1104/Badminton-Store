import type { ReactNode } from "react";

import { ErrorState } from "@/components/ui/error-state";
import { StaffFilters } from "@/features/staff/components/staff-filters";
import { StaffInviteForm } from "@/features/staff/components/staff-invite-form";
import { StaffList } from "@/features/staff/components/staff-list";
import { STAFF_AUTH_DENIED_MESSAGE } from "@/features/staff/constants";
import {
  listStaffMembers,
  type StaffQueryClient,
} from "@/features/staff/queries";
import { readStaffSuccessMessage } from "@/features/staff/success-message";
import { parseStaffExplorerQuery } from "@/features/staff/validation";
import {
  type AuthorizationSupabaseClient,
  authorizeCmsAdminRequest,
} from "@/lib/auth/authorization";
import { createSupabaseServerClient } from "@/lib/supabase/server";

export const dynamic = "force-dynamic";

type StaffPageProps = {
  searchParams?: Promise<Record<string, string | string[] | undefined>>;
};

export default async function StaffPage({ searchParams }: StaffPageProps) {
  const resolvedSearchParams = (await searchParams) ?? {};
  const query = parseStaffExplorerQuery(resolvedSearchParams);
  const successMessage = readStaffSuccessMessage(resolvedSearchParams.success);

  const supabase = await createSupabaseServerClient();
  const authorization = await authorizeCmsAdminRequest(
    supabase as unknown as AuthorizationSupabaseClient,
  );

  if (authorization.kind !== "authorized") {
    return (
      <StaffExplorerShell>
        <ErrorState
          title="Staff management unavailable"
          description={STAFF_AUTH_DENIED_MESSAGE}
        />
      </StaffExplorerShell>
    );
  }

  const listed = await listStaffMembers({
    supabase: supabase as unknown as StaffQueryClient,
    query,
  });

  return (
    <StaffExplorerShell>
      {successMessage ? (
        <p
          role="status"
          className="rounded-2xl border border-emerald-300/20 bg-emerald-300/10 px-4 py-3 text-sm text-emerald-100"
        >
          {successMessage}
        </p>
      ) : null}
      <StaffInviteForm />
      <StaffFilters query={query} />
      {!listed.ok ? (
        <ErrorState
          title="Staff management unavailable"
          description={listed.message}
        />
      ) : (
        <StaffList
          result={listed.result}
          currentActorId={authorization.profile.id}
        />
      )}
    </StaffExplorerShell>
  );
}

function StaffExplorerShell({ children }: { children: ReactNode }) {
  return (
    <div className="mx-auto max-w-6xl space-y-8">
      <header className="space-y-3">
        <p className="text-sm font-semibold uppercase tracking-[0.3em] text-emerald-300">
          Staff
        </p>
        <h1 className="text-3xl font-semibold tracking-tight text-white sm:text-4xl">
          Staff management
        </h1>
        <p className="max-w-3xl text-base leading-7 text-slate-300">
          Admin-only invitations, activation, and trusted role changes. Staff
          directory reads are server-side with bounded pagination and
          PII-minimized fields.
        </p>
      </header>
      {children}
    </div>
  );
}
