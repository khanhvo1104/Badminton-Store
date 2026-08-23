import type { ReactNode } from "react";

import { ErrorState } from "@/components/ui/error-state";
import { AuditFilters } from "@/features/audit/components/audit-filters";
import { AuditTimeline } from "@/features/audit/components/audit-timeline";
import { AUDIT_AUTH_DENIED_MESSAGE } from "@/features/audit/constants";
import {
  listAuditEvents,
  type AuditQueryClient,
} from "@/features/audit/queries";
import { parseAuditExplorerQuery } from "@/features/audit/validation";
import {
  type AuthorizationSupabaseClient,
  authorizeCmsAdminRequest,
} from "@/lib/auth/authorization";
import { createSupabaseServerClient } from "@/lib/supabase/server";

export const dynamic = "force-dynamic";

type AuditPageProps = {
  searchParams?: Promise<Record<string, string | string[] | undefined>>;
};

export default async function AuditPage({ searchParams }: AuditPageProps) {
  const resolvedSearchParams = (await searchParams) ?? {};
  const query = parseAuditExplorerQuery(resolvedSearchParams);

  const supabase = await createSupabaseServerClient();
  const authorization = await authorizeCmsAdminRequest(
    supabase as unknown as AuthorizationSupabaseClient,
  );

  if (authorization.kind !== "authorized") {
    return (
      <AuditExplorerShell>
        <ErrorState
          title="Audit trail unavailable"
          description={AUDIT_AUTH_DENIED_MESSAGE}
        />
      </AuditExplorerShell>
    );
  }

  const listed = await listAuditEvents({
    supabase: supabase as unknown as AuditQueryClient,
    query,
  });

  return (
    <AuditExplorerShell>
      <AuditFilters query={query} />
      {!listed.ok ? (
        <ErrorState
          title="Audit trail unavailable"
          description={listed.message}
        />
      ) : (
        <AuditTimeline result={listed.result} />
      )}
    </AuditExplorerShell>
  );
}

function AuditExplorerShell({ children }: { children: ReactNode }) {
  return (
    <div className="mx-auto max-w-6xl space-y-8">
      <header className="space-y-3">
        <p className="text-sm font-semibold uppercase tracking-[0.3em] text-emerald-300">
          Audit
        </p>
        <h1 className="text-3xl font-semibold tracking-tight text-white sm:text-4xl">
          Privileged audit trail
        </h1>
        <p className="max-w-3xl text-base leading-7 text-slate-300">
          Immutable record of privileged CMS catalog, inventory, order, media,
          and staff changes. Metadata is allowlisted and sanitized; customer
          checkout activity is excluded.
        </p>
      </header>
      {children}
    </div>
  );
}
