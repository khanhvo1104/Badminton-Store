import { createServerClient, type CookieOptions } from "@supabase/ssr";
import { cookies } from "next/headers";

import { getPublicEnvironment } from "@/lib/env/public-env";

type CookieStore = Awaited<ReturnType<typeof cookies>>;

type CreateSupabaseServerClientOptions = {
  cookieStore?: CookieStore;
  canSetCookies?: boolean;
};

export async function createSupabaseServerClient(
  options: CreateSupabaseServerClientOptions = {},
) {
  const cookieStore = options.cookieStore ?? (await cookies());
  const environment = getPublicEnvironment();

  return createServerClient(
    environment.supabaseUrl,
    environment.supabasePublishableKey,
    {
      cookies: options.canSetCookies
        ? {
            getAll() {
              return cookieStore.getAll();
            },
            setAll(cookiesToSet) {
              cookiesToSet.forEach(
                ({ name, value, options: cookieOptions }) => {
                  cookieStore.set(name, value, cookieOptions as CookieOptions);
                },
              );
            },
          }
        : {
            getAll() {
              return cookieStore.getAll();
            },
          },
    },
  );
}
