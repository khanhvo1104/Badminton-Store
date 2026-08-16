import { describe, expect, it, vi } from "vitest";

import {
  CATEGORY_PARENT_CYCLE_MESSAGE,
  CATEGORY_PARENT_INVALID_MESSAGE,
} from "@/features/categories/constants";
import {
  assertSafeCategoryParent,
  collectDescendantIds,
  type HierarchyClient,
  type HierarchyNode,
  validateParentAssignment,
} from "@/features/categories/hierarchy";

function uuidAt(index: number): string {
  const hex = index.toString(16).padStart(12, "0");
  return `10000000-0000-4000-8000-${hex}`;
}

describe("category hierarchy helpers", () => {
  const nodes = [
    { id: "11111111-1111-4111-8111-111111111111", parentId: null },
    {
      id: "22222222-2222-4222-8222-222222222222",
      parentId: "11111111-1111-4111-8111-111111111111",
    },
    {
      id: "33333333-3333-4333-8333-333333333333",
      parentId: "22222222-2222-4222-8222-222222222222",
    },
  ];

  it("rejects self and descendant parents", () => {
    expect(
      validateParentAssignment({
        categoryId: "11111111-1111-4111-8111-111111111111",
        parentId: "11111111-1111-4111-8111-111111111111",
        nodes,
      }),
    ).toEqual({ ok: false, message: CATEGORY_PARENT_CYCLE_MESSAGE });

    expect(
      validateParentAssignment({
        categoryId: "11111111-1111-4111-8111-111111111111",
        parentId: "33333333-3333-4333-8333-333333333333",
        nodes,
      }),
    ).toEqual({ ok: false, message: CATEGORY_PARENT_CYCLE_MESSAGE });
  });

  it("allows valid parents and collects descendants", () => {
    expect(
      validateParentAssignment({
        categoryId: "33333333-3333-4333-8333-333333333333",
        parentId: "11111111-1111-4111-8111-111111111111",
        nodes,
      }),
    ).toEqual({ ok: true });

    expect(
      collectDescendantIds(nodes, "11111111-1111-4111-8111-111111111111"),
    ).toEqual({
      ok: true,
      descendants: new Set([
        "22222222-2222-4222-8222-222222222222",
        "33333333-3333-4333-8333-333333333333",
      ]),
    });
  });

  it("fails closed when a descendant sits beyond the traversal cutoff", () => {
    // Chain: root -> c1 -> c2 -> c3 -> deepDescendant
    const chain: HierarchyNode[] = [
      { id: uuidAt(1), parentId: null },
      { id: uuidAt(2), parentId: uuidAt(1) },
      { id: uuidAt(3), parentId: uuidAt(2) },
      { id: uuidAt(4), parentId: uuidAt(3) },
      { id: uuidAt(5), parentId: uuidAt(4) },
    ];

    const collected = collectDescendantIds(chain, uuidAt(1), { maxNodes: 2 });
    expect(collected).toEqual({ ok: false, reason: "truncated" });

    // Deep descendant is beyond cutoff; must NOT be treated as safe.
    expect(
      validateParentAssignment({
        categoryId: uuidAt(1),
        parentId: uuidAt(5),
        nodes: chain,
        maxTraversalNodes: 2,
      }),
    ).toEqual({ ok: false, message: CATEGORY_PARENT_INVALID_MESSAGE });
  });

  it("fails closed when the fetched hierarchy graph may be truncated", async () => {
    const fetchLimit = 3;
    const rows = Array.from({ length: fetchLimit }, (_, index) => ({
      id: uuidAt(index + 1),
      parent_id: index === 0 ? null : uuidAt(index),
    }));

    const limit = vi.fn().mockResolvedValue({ data: rows, error: null });
    const client: HierarchyClient = {
      from: () => ({
        select: () => ({ limit }),
      }),
    };

    await expect(
      assertSafeCategoryParent(client, {
        categoryId: uuidAt(1),
        parentId: uuidAt(2),
        graphFetchLimit: fetchLimit,
      }),
    ).resolves.toEqual({
      ok: false,
      message: CATEGORY_PARENT_INVALID_MESSAGE,
    });

    expect(limit).toHaveBeenCalledWith(fetchLimit);
  });
});
