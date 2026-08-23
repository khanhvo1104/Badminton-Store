import {
  AUDIT_LIST_PATH,
  AUDIT_PAGE_SIZE_DEFAULT,
  AUDIT_PAGE_SIZE_MAX,
  AUDIT_ACTIONS,
  AUDIT_ENTITY_TYPES,
} from "@/features/audit/constants";
import type {
  AuditActionFilter,
  AuditEntityFilter,
  AuditExplorerQuery,
} from "@/features/audit/types";
import { parseIsoTimestamp } from "@/features/audit/mappers";
import { isValidUuid } from "@/features/products/validation";

type SearchParamsInput =
  | Record<string, string | string[] | undefined>
  | URLSearchParams;

export function parseAuditExplorerQuery(
  searchParams: SearchParamsInput,
): AuditExplorerQuery {
  const cursorOccurredAt = parseIsoDate(
    readSearchParam(searchParams, "cursorAt"),
  );
  const cursorId = parseCursorId(readSearchParam(searchParams, "cursorId"));
  const cursor = normalizeCursorPair(cursorOccurredAt, cursorId);

  return {
    entityType: parseEntityFilter(readSearchParam(searchParams, "entity")),
    action: parseActionFilter(readSearchParam(searchParams, "action")),
    actorId: parseActorId(readSearchParam(searchParams, "actor")),
    occurredFrom: parseIsoDate(readSearchParam(searchParams, "from")),
    occurredTo: parseIsoDate(readSearchParam(searchParams, "to")),
    cursorOccurredAt: cursor.occurredAt,
    cursorId: cursor.id,
    limit: clampInt(
      parseStrictPositiveInt(readSearchParam(searchParams, "limit")),
      1,
      AUDIT_PAGE_SIZE_MAX,
      AUDIT_PAGE_SIZE_DEFAULT,
    ),
  };
}

export function normalizeCursorPair(
  occurredAt: string | null,
  id: string | null,
): { occurredAt: string | null; id: string | null } {
  if (occurredAt === null && id === null) {
    return { occurredAt: null, id: null };
  }
  if (occurredAt !== null && id !== null) {
    return { occurredAt, id };
  }
  return { occurredAt: null, id: null };
}

export function auditExplorerHasActiveFilters(
  query: AuditExplorerQuery,
): boolean {
  return (
    query.entityType !== "all" ||
    query.action !== "all" ||
    query.actorId !== null ||
    query.occurredFrom !== null ||
    query.occurredTo !== null
  );
}

export function auditExplorerHref(
  query: AuditExplorerQuery,
  nextCursor?: { occurredAt: string; id: string } | null,
): string {
  const params = new URLSearchParams();

  if (query.entityType !== "all") {
    params.set("entity", query.entityType);
  }
  if (query.action !== "all") {
    params.set("action", query.action);
  }
  if (query.actorId) {
    params.set("actor", query.actorId);
  }
  if (query.occurredFrom) {
    params.set("from", query.occurredFrom);
  }
  if (query.occurredTo) {
    params.set("to", query.occurredTo);
  }
  if (query.limit !== AUDIT_PAGE_SIZE_DEFAULT) {
    params.set("limit", String(query.limit));
  }

  const cursor = nextCursor ?? null;
  if (cursor) {
    params.set("cursorAt", cursor.occurredAt);
    params.set("cursorId", cursor.id);
  }

  const queryString = params.toString();
  return queryString ? `${AUDIT_LIST_PATH}?${queryString}` : AUDIT_LIST_PATH;
}

export function getAuditExplorerRpcArgs(query: AuditExplorerQuery) {
  return {
    p_entity_type: query.entityType,
    p_action: query.action,
    p_actor_id: query.actorId,
    p_occurred_from: query.occurredFrom,
    p_occurred_to: query.occurredTo,
    p_cursor_occurred_at: query.cursorOccurredAt,
    p_cursor_id: query.cursorId,
    p_limit: query.limit,
  };
}

function parseEntityFilter(value: string | undefined): AuditEntityFilter {
  if (value && AUDIT_ENTITY_TYPES.includes(value as AuditEntityFilter)) {
    return value as AuditEntityFilter;
  }
  return "all";
}

function parseActionFilter(value: string | undefined): AuditActionFilter {
  if (value && AUDIT_ACTIONS.includes(value as AuditActionFilter)) {
    return value as AuditActionFilter;
  }
  return "all";
}

function parseActorId(value: string | undefined): string | null {
  if (!value) {
    return null;
  }
  return isValidUuid(value) ? value : null;
}

function parseCursorId(value: string | undefined): string | null {
  if (!value) {
    return null;
  }
  return isValidUuid(value) ? value : null;
}

function parseIsoDate(value: string | undefined): string | null {
  if (!value) {
    return null;
  }
  return parseIsoTimestamp(value);
}

function readSearchParam(
  searchParams: SearchParamsInput,
  key: string,
): string | undefined {
  if (searchParams instanceof URLSearchParams) {
    return searchParams.get(key) ?? undefined;
  }

  const value = searchParams[key];
  if (Array.isArray(value)) {
    return value[0];
  }
  return value;
}

function parseStrictPositiveInt(value: string | undefined): number | null {
  if (!value || !/^\d+$/.test(value)) {
    return null;
  }
  return Number.parseInt(value, 10);
}

function clampInt(
  value: number | null,
  min: number,
  max: number,
  fallback: number,
): number {
  if (value === null || value < min || value > max) {
    return fallback;
  }
  return value;
}
