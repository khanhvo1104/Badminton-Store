import {
  AUDIT_ACTION_LABELS,
  AUDIT_ACTIONS,
  AUDIT_ENTITY_LABELS,
  AUDIT_ENTITY_TYPES,
} from "@/features/audit/constants";
import type {
  AuditAction,
  AuditEntityType,
  AuditEventItem,
  AuditMetadata,
  CmsAuditRpcRow,
} from "@/features/audit/types";
import { isValidUuid } from "@/features/products/validation";

const ENTITY_SET = new Set<string>(AUDIT_ENTITY_TYPES);
const ACTION_SET = new Set<string>(AUDIT_ACTIONS);

const METADATA_SCHEMA: Record<
  AuditEntityType,
  Partial<Record<AuditAction, readonly string[]>>
> = {
  category: {
    create: ["slug", "name", "is_active"],
    update: [
      "slug",
      "name",
      "is_active",
      "parent_changed",
      "sort_order_changed",
      "image_changed",
    ],
    activate: ["slug", "name", "is_active"],
    deactivate: ["slug", "name", "is_active"],
  },
  brand: {
    create: ["slug", "name", "is_active"],
    update: ["slug", "name", "is_active", "sort_order_changed", "logo_changed"],
    activate: ["slug", "name", "is_active"],
    deactivate: ["slug", "name", "is_active"],
  },
  product: {
    create: ["slug", "name", "status"],
    update: [
      "slug",
      "name",
      "status",
      "is_featured_changed",
      "category_changed",
      "brand_changed",
    ],
    status_change: ["slug", "name", "status", "previous_status"],
  },
  variant: {
    create: ["product_id", "sku", "name", "is_active"],
    update: [
      "product_id",
      "sku",
      "name",
      "is_active",
      "is_default_changed",
      "price_changed",
    ],
    activate: ["product_id", "sku", "name", "is_active"],
    deactivate: ["product_id", "sku", "name", "is_active"],
  },
  inventory: {
    adjust: [
      "operation",
      "reason",
      "on_hand_before",
      "on_hand_after",
      "reorder_changed",
      "backorder_changed",
    ],
  },
  product_media: {
    create: ["product_id", "variant_scope", "is_primary", "sort_order"],
    update: ["product_id", "variant_scope", "is_primary", "sort_order"],
    delete: ["product_id", "variant_scope", "is_primary", "sort_order"],
    set_primary: ["product_id", "variant_scope", "is_primary", "sort_order"],
    reorder: ["product_id", "variant_scope", "is_primary", "sort_order"],
  },
  order: {
    status_transition: ["from_status", "to_status", "has_note"],
    annotate_transition: ["from_status", "to_status", "has_note"],
  },
  staff: {
    invite: [
      "target_id",
      "previous_role",
      "new_role",
      "previous_is_active",
      "new_is_active",
    ],
    activate: [
      "target_id",
      "previous_role",
      "new_role",
      "previous_is_active",
      "new_is_active",
    ],
    deactivate: [
      "target_id",
      "previous_role",
      "new_role",
      "previous_is_active",
      "new_is_active",
    ],
    promote: [
      "target_id",
      "previous_role",
      "new_role",
      "previous_is_active",
      "new_is_active",
    ],
    demote: [
      "target_id",
      "previous_role",
      "new_role",
      "previous_is_active",
      "new_is_active",
    ],
  },
};

export function mapCmsAuditRpcRow(row: unknown): CmsAuditRpcRow | null {
  if (!isRecord(row)) {
    return null;
  }

  return {
    event_id: readNullableString(row.event_id),
    occurred_at: readNullableString(row.occurred_at),
    actor_id: readNullableString(row.actor_id),
    actor_name: readNullableString(row.actor_name),
    entity_type: readNullableString(row.entity_type),
    entity_id: readNullableString(row.entity_id),
    action: readNullableString(row.action),
    metadata: row.metadata,
    has_more: typeof row.has_more === "boolean" ? row.has_more : null,
  };
}

export function mapAuditEventItem(row: CmsAuditRpcRow): AuditEventItem | null {
  if (
    !row.event_id ||
    !isValidUuid(row.event_id) ||
    !row.occurred_at ||
    !row.actor_id ||
    !isValidUuid(row.actor_id) ||
    !row.entity_id ||
    !isValidUuid(row.entity_id)
  ) {
    return null;
  }

  if (
    !row.entity_type ||
    !ENTITY_SET.has(row.entity_type) ||
    row.entity_type === "all"
  ) {
    return null;
  }

  if (!row.action || !ACTION_SET.has(row.action) || row.action === "all") {
    return null;
  }

  const entityType = row.entity_type as AuditEntityType;
  const action = row.action as AuditAction;
  const metadata = parseAuditMetadata(entityType, action, row.metadata);
  if (!metadata) {
    return null;
  }

  return {
    eventId: row.event_id,
    occurredAt: row.occurred_at,
    occurredAtLabel: formatTimestamp(row.occurred_at),
    actorId: row.actor_id,
    actorName: row.actor_name,
    entityType,
    entityId: row.entity_id,
    action,
    metadata,
    summary: buildAuditSummary(entityType, action, metadata),
  };
}

export function parseAuditMetadata(
  entityType: AuditEntityType,
  action: AuditAction,
  value: unknown,
): AuditMetadata | null {
  if (!isRecord(value)) {
    return null;
  }

  const allowed = METADATA_SCHEMA[entityType]?.[action];
  if (!allowed) {
    return null;
  }

  const keys = Object.keys(value);
  if (keys.length === 0 || keys.length > allowed.length) {
    return null;
  }

  const parsed: AuditMetadata = {};
  for (const key of keys) {
    if (!allowed.includes(key)) {
      return null;
    }
    const parsedValue = parseMetadataValue(key, value[key]);
    if (parsedValue === undefined) {
      return null;
    }
    parsed[key] = parsedValue;
  }

  return parsed;
}

function parseMetadataValue(
  key: string,
  value: unknown,
): string | number | boolean | null | undefined {
  if (value === null) {
    return key.endsWith("_id") || key === "name" || key === "sku"
      ? null
      : undefined;
  }

  if (typeof value === "boolean") {
    return value;
  }

  if (typeof value === "number" && Number.isFinite(value)) {
    return value;
  }

  if (typeof value !== "string") {
    return undefined;
  }

  if (key.endsWith("_id")) {
    return isValidUuid(value) ? value : undefined;
  }

  if (key === "slug" && !/^[a-z0-9]+(?:-[a-z0-9]+)*$/.test(value)) {
    return undefined;
  }

  if (
    (key === "name" ||
      key === "sku" ||
      key === "reason" ||
      key === "operation") &&
    value.length > 200
  ) {
    return undefined;
  }

  if (
    (key === "status" ||
      key === "previous_status" ||
      key === "from_status" ||
      key === "to_status" ||
      key === "previous_role" ||
      key === "new_role" ||
      key === "variant_scope") &&
    value.length > 40
  ) {
    return undefined;
  }

  return value;
}

function buildAuditSummary(
  entityType: AuditEntityType,
  action: AuditAction,
  metadata: AuditMetadata,
): string {
  const entityLabel = AUDIT_ENTITY_LABELS[entityType];
  const actionLabel = AUDIT_ACTION_LABELS[action];

  if (entityType === "order" && metadata.from_status && metadata.to_status) {
    return `${entityLabel}: ${String(metadata.from_status)} → ${String(metadata.to_status)}`;
  }

  if (entityType === "inventory" && metadata.operation) {
    return `${entityLabel}: ${String(metadata.operation)} (${String(metadata.on_hand_before)} → ${String(metadata.on_hand_after)})`;
  }

  if (typeof metadata.name === "string" && metadata.name.trim()) {
    return `${entityLabel} ${metadata.name.trim()}: ${actionLabel}`;
  }

  if (typeof metadata.sku === "string" && metadata.sku.trim()) {
    return `${entityLabel} ${metadata.sku.trim()}: ${actionLabel}`;
  }

  return `${entityLabel}: ${actionLabel}`;
}

function formatTimestamp(value: string): string {
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) {
    return value;
  }

  return new Intl.DateTimeFormat("en-GB", {
    dateStyle: "medium",
    timeStyle: "short",
  }).format(date);
}

function readNullableString(value: unknown): string | null {
  return typeof value === "string" ? value : null;
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null;
}
