#!/usr/bin/env node
/**
 * Resolve disposable local Supabase public connection values for CMS Playwright.
 * Writes only a gitignored env file with public CMS values (no service-role key).
 */
import { execFileSync } from "node:child_process";
import { writeFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = dirname(fileURLToPath(import.meta.url));
const repoRoot = resolve(__dirname, "../..");
const cmsRoot = resolve(__dirname, "..");
const envOutPath = resolve(cmsRoot, ".env.e2e.local");

const CMS_BASE_URL = process.env.CMS_E2E_BASE_URL ?? "http://127.0.0.1:3000";

function parseEnvOutput(raw) {
  /** @type {Record<string, string>} */
  const env = {};
  for (const line of raw.split("\n")) {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith("#")) continue;
    const eq = trimmed.indexOf("=");
    if (eq <= 0) continue;
    const key = trimmed.slice(0, eq);
    let value = trimmed.slice(eq + 1);
    if (
      (value.startsWith('"') && value.endsWith('"')) ||
      (value.startsWith("'") && value.endsWith("'"))
    ) {
      value = value.slice(1, -1);
    }
    env[key] = value;
  }
  return env;
}

function loadSupabaseStatusEnv() {
  try {
    const raw = execFileSync("supabase", ["status", "-o", "env"], {
      cwd: repoRoot,
      encoding: "utf8",
      stdio: ["ignore", "pipe", "pipe"],
    });
    return parseEnvOutput(raw);
  } catch (error) {
    const stderr =
      error && typeof error === "object" && "stderr" in error
        ? String(error.stderr)
        : "";
    throw new Error(
      `Local Supabase is not available. Start it with \`supabase start\` from the repo root.${stderr ? ` (${stderr.split("\n")[0]})` : ""}`,
    );
  }
}

const status = loadSupabaseStatusEnv();
const apiUrl = status.API_URL;
const publishableKey = status.PUBLISHABLE_KEY || status.ANON_KEY;

if (!apiUrl || !publishableKey) {
  throw new Error(
    "supabase status did not provide API_URL and a publishable/anon key.",
  );
}

const fileContents = [
  `# Generated for local/CI CMS Playwright only. Do not commit.`,
  `NEXT_PUBLIC_SUPABASE_URL=${apiUrl}`,
  `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY=${publishableKey}`,
  `CMS_SITE_URL=${CMS_BASE_URL}`,
  `CMS_E2E_BASE_URL=${CMS_BASE_URL}`,
  `CMS_E2E_SUPABASE_URL=${apiUrl}`,
  `CMS_E2E_PUBLISHABLE_KEY=${publishableKey}`,
  "",
].join("\n");

writeFileSync(envOutPath, fileContents, { mode: 0o600 });

process.stdout.write(
  `Wrote gitignored CMS E2E public env for local Supabase at ${apiUrl}\n`,
);
