import { cleanupE2EFixtures } from "./fixtures/prepare.mjs";

export default async function globalTeardown() {
  await cleanupE2EFixtures();
}
