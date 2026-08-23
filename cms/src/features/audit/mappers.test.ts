import { describe, expect, it } from "vitest";

import {
  mapAuditEventItem,
  parseAuditMetadata,
  parseIsoTimestamp,
} from "@/features/audit/mappers";
import { normalizeCursorPair } from "@/features/audit/validation";

describe("audit mappers", () => {
  it("maps a valid inventory adjustment event with exact metadata", () => {
    const mapped = mapAuditEventItem({
      event_id: "10000000-0000-4000-8000-000000000001",
      occurred_at: "2026-08-23T10:00:00+00:00",
      actor_id: "20000000-0000-4000-8000-000000000001",
      actor_name: "Admin User",
      entity_type: "inventory",
      entity_id: "30000000-0000-4000-8000-000000000001",
      action: "adjust",
      metadata: {
        operation: "add_stock",
        reason: "restock",
        on_hand_before: 1,
        on_hand_after: 5,
        reorder_changed: false,
        backorder_changed: false,
      },
      has_more: false,
    });

    expect(mapped?.summary).toMatch(/add_stock/i);
    expect(mapped?.metadata.operation).toBe("add_stock");
  });

  it("rejects metadata with disallowed keys", () => {
    expect(
      parseAuditMetadata("order", "status_transition", {
        from_status: "pending",
        to_status: "confirmed",
        has_note: false,
        note: "secret",
      }),
    ).toBeNull();
  });

  it("rejects partial metadata subsets", () => {
    expect(
      parseAuditMetadata("category", "create", {
        slug: "demo",
        name: "Demo",
      }),
    ).toBeNull();
  });

  it("rejects mismatched entity/action combinations", () => {
    expect(
      mapAuditEventItem({
        event_id: "10000000-0000-4000-8000-000000000001",
        occurred_at: "2026-08-23T10:00:00+00:00",
        actor_id: "20000000-0000-4000-8000-000000000001",
        actor_name: "Admin User",
        entity_type: "inventory",
        entity_id: "30000000-0000-4000-8000-000000000001",
        action: "create",
        metadata: {
          operation: "add_stock",
          reason: "restock",
          on_hand_before: 1,
          on_hand_after: 5,
          reorder_changed: false,
          backorder_changed: false,
        },
        has_more: false,
      }),
    ).toBeNull();
  });

  it("rejects malformed timestamps and entity ids", () => {
    expect(parseIsoTimestamp("not-a-date")).toBeNull();
    expect(parseIsoTimestamp("2026-08-23T10:00:00")).toBeNull();
    expect(parseIsoTimestamp("2026-08-23 10:00:00+00:00")).toBeNull();
    expect(parseIsoTimestamp("2026-08-23T10:00:00+00:00")).toBe(
      "2026-08-23T10:00:00+00:00",
    );
    expect(
      mapAuditEventItem({
        event_id: "not-a-uuid",
        occurred_at: "2026-08-23T10:00:00+00:00",
        actor_id: "20000000-0000-4000-8000-000000000001",
        actor_name: "Admin User",
        entity_type: "staff",
        entity_id: "30000000-0000-4000-8000-000000000001",
        action: "invite",
        metadata: {
          target_id: "40000000-0000-4000-8000-000000000001",
          previous_role: "customer",
          new_role: "staff",
          previous_is_active: true,
          new_is_active: true,
        },
        has_more: false,
      }),
    ).toBeNull();
    expect(
      mapAuditEventItem({
        event_id: "10000000-0000-4000-8000-000000000001",
        occurred_at: "not-a-date",
        actor_id: "20000000-0000-4000-8000-000000000001",
        actor_name: "Admin User",
        entity_type: "staff",
        entity_id: "30000000-0000-4000-8000-000000000001",
        action: "invite",
        metadata: {
          target_id: "40000000-0000-4000-8000-000000000001",
          previous_role: "customer",
          new_role: "staff",
          previous_is_active: true,
          new_is_active: true,
        },
        has_more: false,
      }),
    ).toBeNull();
  });
});

describe("audit cursor parsing", () => {
  it("discards incomplete cursor pairs", () => {
    expect(normalizeCursorPair("2026-08-23T10:00:00+00:00", null)).toEqual({
      occurredAt: null,
      id: null,
    });
    expect(
      normalizeCursorPair(null, "10000000-0000-4000-8000-000000000001"),
    ).toEqual({ occurredAt: null, id: null });
  });
});
