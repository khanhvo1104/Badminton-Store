import { createServerClient, type CookieOptions } from "@supabase/ssr";
import { NextResponse, type NextRequest } from "next/server";

import { getPublicEnvironment } from "@/lib/env/public-env";

type ProxySupabaseClient = {
  auth: {
    getClaims: () => Promise<unknown>;
  };
};

type CreateProxyClient = (context: {
  request: NextRequest;
  response: NextResponse;
}) => ProxySupabaseClient;

export async function refreshSupabaseSession(
  request: NextRequest,
  createClient: CreateProxyClient = createSupabaseProxyClient,
) {
  let requestHeaders = new Headers(request.headers);
  let response = NextResponse.next({
    request: {
      headers: requestHeaders,
    },
  });

  const client = createClient({
    request,
    response,
  });

  if ("__setResponse" in client && typeof client.__setResponse === "function") {
    client.__setResponse((nextResponse: NextResponse, nextHeaders: Headers) => {
      response = nextResponse;
      requestHeaders = nextHeaders;
    });
  }

  await client.auth.getClaims();

  return response;
}

type ProxyClientWithResponseSetter = ProxySupabaseClient & {
  __setResponse?: (
    setResponse: (response: NextResponse, requestHeaders: Headers) => void,
  ) => void;
};

export function createSupabaseProxyClient({
  request,
  response: initialResponse,
}: {
  request: NextRequest;
  response: NextResponse;
}): ProxyClientWithResponseSetter {
  const environment = getPublicEnvironment();

  let response = initialResponse;
  const requestHeaders = new Headers(request.headers);
  let onResponseUpdate:
    | ((nextResponse: NextResponse, nextHeaders: Headers) => void)
    | undefined;

  const supabase = createServerClient(
    environment.supabaseUrl,
    environment.supabasePublishableKey,
    {
      cookies: {
        getAll() {
          return request.cookies.getAll();
        },
        setAll(cookiesToSet, headers) {
          cookiesToSet.forEach(({ name, value }) => {
            request.cookies.set(name, value);
          });

          const forwardedCookies = request.cookies.toString();
          if (forwardedCookies) {
            requestHeaders.set("cookie", forwardedCookies);
          } else {
            requestHeaders.delete("cookie");
          }

          const nextResponse = NextResponse.next({
            request: {
              headers: requestHeaders,
            },
          });

          response.headers.forEach((value, key) => {
            nextResponse.headers.set(key, value);
          });
          response.cookies.getAll().forEach((cookie) => {
            nextResponse.cookies.set(cookie);
          });

          Object.entries(headers).forEach(([key, value]) => {
            nextResponse.headers.set(key, value);
          });

          cookiesToSet.forEach(({ name, value, options }) => {
            nextResponse.cookies.set(name, value, options as CookieOptions);
          });

          response = nextResponse;
          onResponseUpdate?.(response, requestHeaders);
        },
      },
    },
  );

  return Object.assign(supabase, {
    __setResponse(setResponse: typeof onResponseUpdate) {
      onResponseUpdate = setResponse;
    },
  });
}
