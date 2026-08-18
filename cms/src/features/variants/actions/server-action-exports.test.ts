import { readdirSync, readFileSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

import { describe, expect, it } from "vitest";

const actionsDir = path.dirname(fileURLToPath(import.meta.url));

function stripComments(source: string): string {
  return source
    .replace(/\/\*[\s\S]*?\*\//g, "")
    .replace(/(^|[^:])\/\/.*$/gm, "$1");
}

function listUseServerModules(directory: string): string[] {
  return readdirSync(directory)
    .filter((name) => name.endsWith(".ts") && !name.endsWith(".test.ts"))
    .map((name) => path.join(directory, name))
    .filter((filePath) => {
      const source = readFileSync(filePath, "utf8");
      return /^\s*["']use server["']\s*;/m.test(source);
    });
}

function findDisallowedRuntimeExports(source: string): string[] {
  const body = stripComments(source);
  const disallowed: string[] = [];

  for (const match of body.matchAll(/^export\s+(.+)$/gm)) {
    const statement = match[1].trim();
    const firstLine = statement.split(/\r?\n/, 1)[0] ?? statement;

    if (
      statement.startsWith("async function ") ||
      statement.startsWith("type ") ||
      statement.startsWith("interface ") ||
      /^type\s*\{/.test(statement)
    ) {
      continue;
    }

    disallowed.push(firstLine);
  }

  return disallowed;
}

describe("variant server action export boundary", () => {
  it("keeps use server modules limited to async function exports", () => {
    const modules = listUseServerModules(actionsDir);
    expect(modules.map((filePath) => path.basename(filePath)).sort()).toEqual([
      "create-variant.ts",
      "update-variant.ts",
    ]);

    for (const filePath of modules) {
      const source = readFileSync(filePath, "utf8");
      expect(
        findDisallowedRuntimeExports(source),
        `${path.basename(filePath)} must not export non-async runtime values`,
      ).toEqual([]);
    }
  });
});
