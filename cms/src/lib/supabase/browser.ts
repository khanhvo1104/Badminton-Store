import { createBrowserClient } from "@supabase/ssr";

import { getPublicEnvironment } from "@/lib/env/public-env";

export function createSupabaseBrowserClient() {
  const environment = getPublicEnvironment();

  return createBrowserClient(
    environment.supabaseUrl,
    environment.supabasePublishableKey,
  );
}
