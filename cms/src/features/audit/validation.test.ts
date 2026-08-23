import { describe, expect, it } from "vitest";

import {
  auditExplorerHasActiveFilters,
  auditExplorerHref,
  parseAuditExplorerQuery,
} from "@/features/audit/validation";

describe("audit validation", () => {
  it("parses bounded filters and ignores invalid actor ids", () => {
    const query = parseAuditExplorerQuery({
      entity: "order",
      action: "status_transition",
      actor: "not-a-uuid",
      limit: "999",
    });

    expect(query.entityType).toBe("order");
    expect(query.action).toBe("status_transition");
    expect(query.actorId).toBeNull();
    expect(query.limit).toBe(25);
  });

  it("builds cursor pagination links", () => {
    const href = auditExplorerHref(
      parseAuditExplorerQuery({ entity: "staff" }),
      {
        occurredAt: "2026-08-23T10:00:00.000Z",
        id: "10000000-0000-4000-8000-000000000001",
      },
    );

    expect(href).toContain("cursorAt=");
    expect(href).toContain("cursorId=10000000-0000-4000-8000-000000000001");
  });

  it("detects active filters", () => {
    expect(
      auditExplorerHasActiveFilters(
        parseAuditExplorerQuery({ entity: "brand" }),
      ),
    ).toBe(true);
    expect(auditExplorerHasActiveFilters(parseAuditExplorerQuery({}))).toBe(
      false,
    );
  });
});
