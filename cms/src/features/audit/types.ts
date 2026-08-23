import type {
  AUDIT_ACTIONS,
  AUDIT_ENTITY_TYPES,
} from "@/features/audit/constants";

export type AuditEntityType = Exclude<
  (typeof AUDIT_ENTITY_TYPES)[number],
  "all"
>;
export type AuditEntityFilter = (typeof AUDIT_ENTITY_TYPES)[number];
export type AuditAction = Exclude<(typeof AUDIT_ACTIONS)[number], "all">;
export type AuditActionFilter = (typeof AUDIT_ACTIONS)[number];

export type AuditMetadata = Record<string, string | number | boolean | null>;

export type AuditEventItem = {
  eventId: string;
  occurredAt: string;
  occurredAtLabel: string;
  actorId: string;
  actorName: string | null;
  entityType: AuditEntityType;
  entityId: string;
  action: AuditAction;
  metadata: AuditMetadata;
  summary: string;
};

export type AuditExplorerQuery = {
  entityType: AuditEntityFilter;
  action: AuditActionFilter;
  actorId: string | null;
  occurredFrom: string | null;
  occurredTo: string | null;
  cursorOccurredAt: string | null;
  cursorId: string | null;
  limit: number;
};

export type AuditListResult = {
  items: AuditEventItem[];
  hasMore: boolean;
  nextCursor: { occurredAt: string; id: string } | null;
  query: AuditExplorerQuery;
  hasActiveFilters: boolean;
};

export type AuditExplorerLoadResult =
  | { ok: true; result: AuditListResult }
  | { ok: false; message: string };

export type CmsAuditRpcRow = {
  event_id: string | null;
  occurred_at: string | null;
  actor_id: string | null;
  actor_name: string | null;
  entity_type: string | null;
  entity_id: string | null;
  action: string | null;
  metadata: unknown;
  has_more: boolean | null;
};
