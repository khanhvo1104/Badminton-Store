import { readFileSync, existsSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

import { defineConfig, devices } from "@playwright/test";

const __dirname = dirname(fileURLToPath(import.meta.url));
const envPath = resolve(__dirname, ".env.e2e.local");

function loadGitignoredEnv() {
  if (!existsSync(envPath)) {
    return;
  }

  const raw = readFileSync(envPath, "utf8");
  for (const line of raw.split("\n")) {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith("#")) continue;
    const eq = trimmed.indexOf("=");
    if (eq <= 0) continue;
    const key = trimmed.slice(0, eq);
    const value = trimmed.slice(eq + 1);
    if (!(key in process.env)) {
      process.env[key] = value;
    }
  }
}

loadGitignoredEnv();

const baseURL = process.env.CMS_E2E_BASE_URL ?? "http://127.0.0.1:3000";

export default defineConfig({
  testDir: "./e2e",
  fullyParallel: false,
  workers: 1,
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 1 : 0,
  timeout: 60_000,
  expect: { timeout: 15_000 },
  reporter: process.env.CI ? [["github"], ["list"]] : [["list"]],
  globalSetup: "./e2e/global-setup.mjs",
  globalTeardown: "./e2e/global-teardown.mjs",
  use: {
    baseURL,
    trace: "retain-on-failure",
    screenshot: "only-on-failure",
    video: "retain-on-failure",
    actionTimeout: 15_000,
  },
  projects: [
    {
      name: "chromium",
      testIgnore: /mobile\.spec\.ts/,
      use: { ...devices["Desktop Chrome"] },
    },
    {
      name: "mobile-chrome",
      testMatch: /mobile\.spec\.ts/,
      use: { ...devices["Pixel 5"] },
    },
  ],
  webServer: {
    command: "node scripts/e2e-start.mjs",
    url: baseURL,
    reuseExistingServer: false,
    timeout: 120_000,
  },
});
