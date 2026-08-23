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

const ENTITY_ACTIONS: Record<AuditEntityType, readonly AuditAction[]> = {
  category: ["create", "update", "activate", "deactivate"],
  brand: ["create", "update", "activate", "deactivate"],
  product: ["create", "update", "status_change"],
  variant: ["create", "update", "activate", "deactivate"],
  inventory: ["adjust"],
  product_media: ["create", "update", "delete", "set_primary", "reorder"],
  order: ["status_transition", "annotate_transition"],
  staff: ["invite", "activate", "deactivate", "promote", "demote"],
};

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
    activate: [
      "product_id",
      "sku",
      "name",
      "is_active",
      "is_default_changed",
      "price_changed",
    ],
    deactivate: [
      "product_id",
      "sku",
      "name",
      "is_active",
      "is_default_changed",
      "price_changed",
    ],
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

const PRODUCT_STATUSES = new Set(["draft", "active", "inactive", "archived"]);
const ORDER_STATUSES = new Set([
  "pending",
  "confirmed",
  "preparing",
  "shipping",
  "delivered",
  "cancelled",
  "returned",
]);
const STAFF_ROLES = new Set(["customer", "staff", "admin"]);
const STAFF_NEW_ROLES = new Set(["staff", "admin"]);
const INVENTORY_OPERATIONS = new Set([
  "add_stock",
  "remove_stock",
  "set_on_hand",
  "set_reorder_level",
  "set_allow_backorder",
]);
const MEDIA_SCOPES = new Set(["general", "variant"]);

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
    !parseIsoTimestamp(row.occurred_at) ||
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

  if (!isValidEntityAction(entityType, action)) {
    return null;
  }

  const metadata = parseAuditMetadata(entityType, action, row.metadata);
  if (!metadata) {
    return null;
  }

  const occurredAtLabel = formatTimestamp(row.occurred_at);
  if (!occurredAtLabel) {
    return null;
  }

  return {
    eventId: row.event_id,
    occurredAt: row.occurred_at,
    occurredAtLabel,
    actorId: row.actor_id,
    actorName: row.actor_name,
    entityType,
    entityId: row.entity_id,
    action,
    metadata,
    summary: buildAuditSummary(entityType, action, metadata),
  };
}

export function isValidEntityAction(
  entityType: AuditEntityType,
  action: AuditAction,
): boolean {
  return ENTITY_ACTIONS[entityType].includes(action);
}

export function parseAuditMetadata(
  entityType: AuditEntityType,
  action: AuditAction,
  value: unknown,
): AuditMetadata | null {
  if (!isRecord(value)) {
    return null;
  }

  const required = METADATA_SCHEMA[entityType]?.[action];
  if (!required) {
    return null;
  }

  const keys = Object.keys(value);
  if (keys.length !== required.length) {
    return null;
  }

  for (const key of required) {
    if (!(key in value)) {
      return null;
    }
  }

  const parsed: AuditMetadata = {};
  for (const key of required) {
    const parsedValue = parseMetadataValue(entityType, action, key, value[key]);
    if (parsedValue === undefined) {
      return null;
    }
    parsed[key] = parsedValue;
  }

  return parsed;
}

function parseMetadataValue(
  entityType: AuditEntityType,
  action: AuditAction,
  key: string,
  value: unknown,
): string | number | boolean | null | undefined {
  if (key === "product_id" || key === "target_id") {
    return typeof value === "string" && isValidUuid(value) ? value : undefined;
  }

  if (key === "name" && entityType === "variant") {
    if (value === null) {
      return null;
    }
    if (typeof value !== "string") {
      return undefined;
    }
    const trimmed = value.trim();
    return trimmed.length >= 1 && trimmed.length <= 200 ? value : undefined;
  }

  if (typeof value === "boolean") {
    if (
      key.endsWith("_changed") ||
      key === "is_active" ||
      key === "is_primary" ||
      key === "has_note" ||
      key.startsWith("previous_is_") ||
      key.startsWith("new_is_")
    ) {
      return value;
    }
    return undefined;
  }

  if (typeof value === "number" && Number.isInteger(value)) {
    if (key === "on_hand_before" || key === "on_hand_after") {
      return value >= 0 ? value : undefined;
    }
    if (key === "sort_order") {
      return value >= -1_000_000 && value <= 1_000_000 ? value : undefined;
    }
    return undefined;
  }

  if (typeof value !== "string") {
    return undefined;
  }

  if (key === "slug") {
    return /^[a-z0-9]+(?:-[a-z0-9]+)*$/.test(value) && value.length <= 120
      ? value
      : undefined;
  }

  if (key === "name") {
    const trimmed = value.trim();
    return trimmed.length >= 1 && trimmed.length <= 120 ? value : undefined;
  }

  if (key === "sku") {
    const trimmed = value.trim();
    return trimmed.length >= 1 && trimmed.length <= 80 ? value : undefined;
  }

  if (key === "reason") {
    const trimmed = value.trim();
    return trimmed.length >= 1 && trimmed.length <= 80 ? value : undefined;
  }

  if (key === "operation") {
    return INVENTORY_OPERATIONS.has(value) ? value : undefined;
  }

  if (key === "status" || key === "previous_status") {
    return PRODUCT_STATUSES.has(value) ? value : undefined;
  }

  if (key === "from_status" || key === "to_status") {
    return ORDER_STATUSES.has(value) ? value : undefined;
  }

  if (key === "previous_role") {
    return STAFF_ROLES.has(value) ? value : undefined;
  }

  if (key === "new_role") {
    return STAFF_NEW_ROLES.has(value) ? value : undefined;
  }

  if (key === "variant_scope") {
    return MEDIA_SCOPES.has(value) ? value : undefined;
  }

  return undefined;
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

export function parseIsoTimestamp(value: string): string | null {
  const parsed = Date.parse(value);
  if (Number.isNaN(parsed)) {
    return null;
  }
  return new Date(parsed).toISOString();
}

function formatTimestamp(value: string): string | null {
  if (!parseIsoTimestamp(value)) {
    return null;
  }

  const date = new Date(value);
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
