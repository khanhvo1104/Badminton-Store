import Link from "next/link";

import {
  AUDIT_ACTION_LABELS,
  AUDIT_ACTIONS,
  AUDIT_ENTITY_LABELS,
  AUDIT_ENTITY_TYPES,
  AUDIT_LIST_PATH,
} from "@/features/audit/constants";
import type { AuditExplorerQuery } from "@/features/audit/types";

type AuditFiltersProps = {
  query: AuditExplorerQuery;
};

export function AuditFilters({ query }: AuditFiltersProps) {
  return (
    <form
      action={AUDIT_LIST_PATH}
      method="get"
      className="grid gap-4 rounded-3xl border border-white/10 bg-slate-900/60 p-4 sm:grid-cols-2 lg:grid-cols-4"
    >
      <label className="space-y-2 text-sm text-slate-300">
        <span className="font-semibold text-white">Entity</span>
        <select
          name="entity"
          defaultValue={query.entityType}
          className="w-full rounded-2xl border border-white/10 bg-slate-950 px-3 py-2 text-white"
        >
          {AUDIT_ENTITY_TYPES.map((entityType) => (
            <option key={entityType} value={entityType}>
              {entityType === "all"
                ? "All entities"
                : AUDIT_ENTITY_LABELS[entityType]}
            </option>
          ))}
        </select>
      </label>

      <label className="space-y-2 text-sm text-slate-300">
        <span className="font-semibold text-white">Action</span>
        <select
          name="action"
          defaultValue={query.action}
          className="w-full rounded-2xl border border-white/10 bg-slate-950 px-3 py-2 text-white"
        >
          {AUDIT_ACTIONS.map((action) => (
            <option key={action} value={action}>
              {action === "all" ? "All actions" : AUDIT_ACTION_LABELS[action]}
            </option>
          ))}
        </select>
      </label>

      <label className="space-y-2 text-sm text-slate-300">
        <span className="font-semibold text-white">From</span>
        <input
          type="datetime-local"
          name="from"
          defaultValue={toDateTimeLocal(query.occurredFrom)}
          className="w-full rounded-2xl border border-white/10 bg-slate-950 px-3 py-2 text-white"
        />
      </label>

      <label className="space-y-2 text-sm text-slate-300">
        <span className="font-semibold text-white">To</span>
        <input
          type="datetime-local"
          name="to"
          defaultValue={toDateTimeLocal(query.occurredTo)}
          className="w-full rounded-2xl border border-white/10 bg-slate-950 px-3 py-2 text-white"
        />
      </label>

      <label className="space-y-2 text-sm text-slate-300 sm:col-span-2">
        <span className="font-semibold text-white">Actor ID</span>
        <input
          type="text"
          name="actor"
          defaultValue={query.actorId ?? ""}
          placeholder="Optional profile UUID"
          className="w-full rounded-2xl border border-white/10 bg-slate-950 px-3 py-2 text-white"
        />
      </label>

      <div className="flex items-end gap-3 sm:col-span-2">
        <button
          type="submit"
          className="inline-flex rounded-full bg-emerald-300 px-5 py-3 text-sm font-semibold text-slate-950 transition hover:bg-emerald-200 focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-emerald-200"
        >
          Apply filters
        </button>
        <Link
          href={AUDIT_LIST_PATH}
          className="inline-flex rounded-full border border-white/15 px-5 py-3 text-sm font-semibold text-white transition hover:border-white/30 focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-emerald-200"
        >
          Reset
        </Link>
      </div>
    </form>
  );
}

function toDateTimeLocal(value: string | null): string {
  if (!value) {
    return "";
  }
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) {
    return "";
  }

  const pad = (part: number) => String(part).padStart(2, "0");
  return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())}T${pad(date.getHours())}:${pad(date.getMinutes())}`;
}
