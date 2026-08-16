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

describe("auth server action export boundary", () => {
  it("keeps use server modules limited to async function exports", () => {
    const modules = listUseServerModules(actionsDir);
    expect(modules.map((filePath) => path.basename(filePath)).sort()).toEqual([
      "login.ts",
      "logout.ts",
      "request-password-reset.ts",
      "update-password.ts",
    ]);

    for (const filePath of modules) {
      const source = readFileSync(filePath, "utf8");
      expect(
        findDisallowedRuntimeExports(source),
        `${path.basename(filePath)} must not export non-async runtime values`,
      ).toEqual([]);
    }
  });

  it("keeps login form state outside the use server module", async () => {
    const loginModule = await import("@/features/auth/actions/login");
    const stateModule = await import("@/features/auth/login-form-state");

    expect(Object.keys(loginModule).sort()).toEqual(["login"]);
    expect(loginModule.login.constructor.name).toBe("AsyncFunction");
    expect(stateModule.INITIAL_LOGIN_FORM_STATE).toEqual({
      errorMessage: null,
    });
    expect("INITIAL_LOGIN_FORM_STATE" in loginModule).toBe(false);
  });

  it("keeps recovery form state outside the use server modules", async () => {
    const requestModule = await import(
      "@/features/auth/actions/request-password-reset"
    );
    const updateModule = await import(
      "@/features/auth/actions/update-password"
    );
    const forgotState = await import(
      "@/features/auth/forgot-password-form-state"
    );
    const updateState = await import(
      "@/features/auth/update-password-form-state"
    );

    expect(Object.keys(requestModule).sort()).toEqual(["requestPasswordReset"]);
    expect(Object.keys(updateModule).sort()).toEqual(["updatePassword"]);
    expect(forgotState.INITIAL_FORGOT_PASSWORD_FORM_STATE).toEqual({
      errorMessage: null,
      acknowledgement: null,
    });
    expect(updateState.INITIAL_UPDATE_PASSWORD_FORM_STATE).toEqual({
      errorMessage: null,
    });
  });
});
