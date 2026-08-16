import {
  CATEGORY_GRAPH_FETCH_LIMIT,
  CATEGORY_HIERARCHY_MAX_NODES,
  CATEGORY_PARENT_CYCLE_MESSAGE,
  CATEGORY_PARENT_INVALID_MESSAGE,
} from "@/features/categories/constants";
import { isValidUuid } from "@/features/categories/validation";

export type HierarchyNode = {
  id: string;
  parentId: string | null;
};

export type HierarchyClient = {
  from: (table: "categories") => {
    select: (columns: string) => {
      limit: (count: number) => PromiseLike<{ data: unknown; error: unknown }>;
    };
  };
};

export function clampCategoryGraphLimit(limit = CATEGORY_GRAPH_FETCH_LIMIT) {
  if (!Number.isFinite(limit) || limit < 1) {
    return CATEGORY_GRAPH_FETCH_LIMIT;
  }
  return Math.min(Math.floor(limit), CATEGORY_GRAPH_FETCH_LIMIT);
}

export function collectDescendantIds(
  nodes: readonly HierarchyNode[],
  rootId: string,
): Set<string> {
  const childrenByParent = new Map<string, string[]>();
  for (const node of nodes) {
    if (!node.parentId) {
      continue;
    }
    const list = childrenByParent.get(node.parentId) ?? [];
    list.push(node.id);
    childrenByParent.set(node.parentId, list);
  }

  const descendants = new Set<string>();
  const visited = new Set<string>([rootId]);
  const queue = [...(childrenByParent.get(rootId) ?? [])];
  let inspected = 0;

  while (queue.length > 0) {
    inspected += 1;
    if (inspected > CATEGORY_HIERARCHY_MAX_NODES) {
      break;
    }
    const current = queue.shift();
    if (!current || visited.has(current)) {
      continue;
    }
    visited.add(current);
    descendants.add(current);
    for (const child of childrenByParent.get(current) ?? []) {
      if (!visited.has(child)) {
        queue.push(child);
      }
    }
  }

  return descendants;
}

export function validateParentAssignment(input: {
  categoryId?: string | null;
  parentId: string | null;
  nodes: readonly HierarchyNode[];
}): { ok: true } | { ok: false; message: string } {
  const { categoryId = null, parentId, nodes } = input;

  if (parentId === null) {
    return { ok: true };
  }

  if (!isValidUuid(parentId)) {
    return { ok: false, message: CATEGORY_PARENT_INVALID_MESSAGE };
  }

  if (categoryId && parentId === categoryId) {
    return { ok: false, message: CATEGORY_PARENT_CYCLE_MESSAGE };
  }

  const byId = new Map(nodes.map((node) => [node.id, node]));
  if (!byId.has(parentId)) {
    return { ok: false, message: CATEGORY_PARENT_INVALID_MESSAGE };
  }

  if (!categoryId) {
    return { ok: true };
  }

  if (collectDescendantIds(nodes, categoryId).has(parentId)) {
    return { ok: false, message: CATEGORY_PARENT_CYCLE_MESSAGE };
  }

  return { ok: true };
}

export function validateCategoryParentSelection(input: {
  categoryId?: string;
  parentId: string | null;
  nodes: readonly HierarchyNode[];
}):
  | { ok: true }
  | {
      ok: false;
      reason: "self" | "descendant" | "unknown-parent" | "invalid";
    } {
  const { categoryId, parentId, nodes } = input;

  if (parentId === null) {
    return { ok: true };
  }

  if (!parentId) {
    return { ok: false, reason: "invalid" };
  }

  if (categoryId && parentId === categoryId) {
    return { ok: false, reason: "self" };
  }

  const byId = new Map(nodes.map((node) => [node.id, node]));
  if (!byId.has(parentId)) {
    return { ok: false, reason: "unknown-parent" };
  }

  if (!categoryId) {
    return { ok: true };
  }

  if (collectDescendantIds(nodes, categoryId).has(parentId)) {
    return { ok: false, reason: "descendant" };
  }

  return { ok: true };
}

export async function loadHierarchyNodes(
  client: HierarchyClient,
): Promise<HierarchyNode[] | null> {
  try {
    const { data, error } = await client
      .from("categories")
      .select("id, parent_id")
      .limit(clampCategoryGraphLimit());

    if (error || !Array.isArray(data)) {
      return null;
    }

    const nodes: HierarchyNode[] = [];
    for (const row of data) {
      if (!isRecord(row)) {
        continue;
      }
      if (typeof row.id !== "string" || !isValidUuid(row.id)) {
        continue;
      }
      if (row.parent_id !== null && typeof row.parent_id !== "string") {
        continue;
      }
      if (typeof row.parent_id === "string" && !isValidUuid(row.parent_id)) {
        continue;
      }
      nodes.push({ id: row.id, parentId: row.parent_id });
    }
    return nodes;
  } catch {
    return null;
  }
}

export const loadCategoryHierarchyNodes = loadHierarchyNodes;

export async function assertSafeCategoryParent(
  client: HierarchyClient,
  options: {
    categoryId?: string | null;
    parentId: string | null;
  },
): Promise<{ ok: true } | { ok: false; message: string }> {
  const { categoryId = null, parentId } = options;

  if (parentId === null) {
    return { ok: true };
  }

  if (!isValidUuid(parentId)) {
    return { ok: false, message: CATEGORY_PARENT_INVALID_MESSAGE };
  }

  if (categoryId && parentId === categoryId) {
    return { ok: false, message: CATEGORY_PARENT_CYCLE_MESSAGE };
  }

  const nodes = await loadHierarchyNodes(client);
  if (!nodes) {
    return { ok: false, message: CATEGORY_PARENT_INVALID_MESSAGE };
  }

  return validateParentAssignment({ categoryId, parentId, nodes });
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null;
}
