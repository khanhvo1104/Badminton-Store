import Link from "next/link";

import { EmptyState } from "@/components/ui/empty-state";
import { StatusBadge } from "@/components/ui/status-badge";
import {
  AUDIT_ACTION_LABELS,
  AUDIT_EMPTY_MESSAGE,
  AUDIT_ENTITY_LABELS,
  AUDIT_LIST_PATH,
} from "@/features/audit/constants";
import type { AuditEventItem, AuditListResult } from "@/features/audit/types";
import { auditExplorerHref } from "@/features/audit/validation";

type AuditTimelineProps = {
  result: AuditListResult;
};

export function AuditTimeline({ result }: AuditTimelineProps) {
  if (result.items.length === 0) {
    return (
      <EmptyState
        title={
          result.hasActiveFilters
            ? "No matching audit events"
            : "No audit events yet"
        }
        description={
          result.hasActiveFilters
            ? AUDIT_EMPTY_MESSAGE
            : "Privileged CMS changes will appear here once staff or admins mutate catalog, inventory, orders, or staff records."
        }
        action={
          result.hasActiveFilters ? (
            <Link
              href={AUDIT_LIST_PATH}
              className="inline-flex rounded-full bg-emerald-300 px-5 py-3 text-sm font-semibold text-slate-950 transition hover:bg-emerald-200 focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-emerald-200"
            >
              Clear filters
            </Link>
          ) : null
        }
      />
    );
  }

  return (
    <div className="space-y-6">
      <ol className="space-y-4" aria-label="Privileged audit timeline">
        {result.items.map((item) => (
          <AuditTimelineItem key={item.eventId} item={item} />
        ))}
      </ol>

      {result.hasMore && result.nextCursor ? (
        <div className="flex justify-center">
          <Link
            href={auditExplorerHref(result.query, result.nextCursor)}
            className="inline-flex rounded-full border border-white/15 px-5 py-3 text-sm font-semibold text-white transition hover:border-white/30 focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-emerald-200"
          >
            Load older events
          </Link>
        </div>
      ) : null}
    </div>
  );
}

function AuditTimelineItem({ item }: { item: AuditEventItem }) {
  const actorLabel = item.actorName?.trim() || "Staff member";

  return (
    <li className="rounded-3xl border border-white/10 bg-slate-900/60 p-5">
      <div className="flex flex-wrap items-start justify-between gap-3">
        <div className="space-y-2">
          <p className="text-base font-semibold text-white">{item.summary}</p>
          <p className="text-sm text-slate-300">
            {AUDIT_ENTITY_LABELS[item.entityType]} ·{" "}
            {AUDIT_ACTION_LABELS[item.action]}
          </p>
        </div>
        <StatusBadge tone="neutral">{item.occurredAtLabel}</StatusBadge>
      </div>

      <dl className="mt-4 grid gap-3 text-sm text-slate-300 sm:grid-cols-2">
        <div>
          <dt className="text-xs uppercase tracking-[0.2em] text-slate-500">
            Actor
          </dt>
          <dd>{actorLabel}</dd>
        </div>
        <div>
          <dt className="text-xs uppercase tracking-[0.2em] text-slate-500">
            Entity ID
          </dt>
          <dd className="break-all font-mono text-xs text-slate-400">
            {item.entityId}
          </dd>
        </div>
      </dl>
    </li>
  );
}
