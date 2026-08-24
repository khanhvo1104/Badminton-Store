#!/usr/bin/env node
/**
 * Bounded CMS deployment smoke check.
 *
 * Validates the CMS health/readiness contract over HTTPS by default.
 * Pass an explicit http://127.0.0.1 or http://localhost URL for local verification.
 *
 * Usage:
 *   node scripts/smoke-check.mjs --base-url https://cms.example.com
 *   node scripts/smoke-check.mjs --base-url http://127.0.0.1:3000 --allow-localhost
 *
 * Does not embed deployment URLs or credentials.
 */

import { pathToFileURL } from "node:url";

import { smokeCheckMain, runSmokeCheck } from "./lib/smoke-check.mjs";

const isDirectRun =
  process.argv[1] != null &&
  import.meta.url === pathToFileURL(process.argv[1]).href;

if (isDirectRun) {
  const code = await smokeCheckMain(process.argv.slice(2), {
    fetchImpl: fetch,
    write: (line) => {
      process.stderr.write(`${line}\n`);
    },
  });
  process.exit(code);
}

export { runSmokeCheck, smokeCheckMain };
