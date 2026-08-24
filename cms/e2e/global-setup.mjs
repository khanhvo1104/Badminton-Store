import { execFileSync } from "node:child_process";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

import { prepareE2EFixtures } from "./fixtures/prepare.mjs";

const __dirname = dirname(fileURLToPath(import.meta.url));
const cmsRoot = resolve(__dirname, "..");

export default async function globalSetup() {
  execFileSync("node", ["scripts/e2e-local-env.mjs"], {
    cwd: cmsRoot,
    stdio: "inherit",
  });

  await prepareE2EFixtures();
}
