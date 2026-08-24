#!/usr/bin/env node
/**
 * Start the CMS production server with gitignored local E2E public env.
 */
import { spawn } from "node:child_process";
import { existsSync, readFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = dirname(fileURLToPath(import.meta.url));
const cmsRoot = resolve(__dirname, "..");
const envPath = resolve(cmsRoot, ".env.e2e.local");

if (!existsSync(envPath)) {
  throw new Error(
    "Missing cms/.env.e2e.local. Run `npm run test:e2e:env` first while local Supabase is up.",
  );
}

const raw = readFileSync(envPath, "utf8");
for (const line of raw.split("\n")) {
  const trimmed = line.trim();
  if (!trimmed || trimmed.startsWith("#")) continue;
  const eq = trimmed.indexOf("=");
  if (eq <= 0) continue;
  const key = trimmed.slice(0, eq);
  const value = trimmed.slice(eq + 1);
  process.env[key] = value;
}

const child = spawn(
  "npx",
  ["next", "start", "--hostname", "127.0.0.1", "--port", "3000"],
  {
    cwd: cmsRoot,
    env: process.env,
    stdio: "inherit",
  },
);

child.on("exit", (code, signal) => {
  if (signal) {
    process.kill(process.pid, signal);
    return;
  }
  process.exit(code ?? 1);
});
