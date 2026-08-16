import { describe, expect, it } from "vitest";

import { CATEGORY_PARENT_CYCLE_MESSAGE } from "@/features/categories/constants";
import {
  collectDescendantIds,
  validateParentAssignment,
} from "@/features/categories/hierarchy";

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
    ).toEqual(
      new Set([
        "22222222-2222-4222-8222-222222222222",
        "33333333-3333-4333-8333-333333333333",
      ]),
    );
  });
});
