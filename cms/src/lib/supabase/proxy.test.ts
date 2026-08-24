import { NextRequest, NextResponse } from "next/server";
import { beforeEach, describe, expect, it, vi } from "vitest";

const createServerClient = vi.hoisted(() => vi.fn());

vi.mock("@supabase/ssr", () => ({
  createServerClient,
}));

vi.mock("@/lib/env/public-env", () => ({
  getPublicEnvironment: () => ({
    supabaseUrl: "https://demo-project.supabase.co",
    supabasePublishableKey: "public-demo-key",
  }),
}));

describe("refreshSupabaseSession", () => {
  beforeEach(() => {
    createServerClient.mockReset();
  });

  it("refreshes claims and propagates cookies plus no-cache headers", async () => {
    createServerClient.mockImplementation((_url, _key, options) => ({
      auth: {
        getClaims: async () => {
          await options.cookies.setAll(
            [
              {
                name: "sb-demo-auth-token",
                value: "fresh-token",
                options: { path: "/" },
              },
            ],
            {
              "Cache-Control":
                "private, no-cache, no-store, must-revalidate, max-age=0",
              Expires: "0",
              Pragma: "no-cache",
            },
          );

          return { data: { claims: { sub: "staff-1" } }, error: null };
        },
      },
    }));

    const { refreshSupabaseSession } = await import("@/lib/supabase/proxy");

    const request = new NextRequest("https://cms.example.com/dashboard", {
      headers: {
        cookie: "existing=value",
      },
    });

    const response = await refreshSupabaseSession(request);

    expect(request.cookies.get("sb-demo-auth-token")?.value).toBe(
      "fresh-token",
    );
    expect(response.cookies.get("sb-demo-auth-token")?.value).toBe(
      "fresh-token",
    );
    expect(response.headers.get("Cache-Control")).toBe(
      "private, no-cache, no-store, must-revalidate, max-age=0",
    );
    expect(response.headers.get("Expires")).toBe("0");
    expect(response.headers.get("Pragma")).toBe("no-cache");
  });

  it("keeps the default passthrough response when claims do not refresh cookies", async () => {
    createServerClient.mockImplementation(() => ({
      auth: {
        getClaims: async () => ({ data: { claims: null }, error: null }),
      },
    }));

    const { refreshSupabaseSession } = await import("@/lib/supabase/proxy");

    const response = await refreshSupabaseSession(
      new NextRequest("https://cms.example.com/login"),
    );

    expect(response).toBeInstanceOf(NextResponse);
    expect(response.cookies.getAll()).toEqual([]);
  });

  it("returns a safe passthrough when getClaims rejects after cookie refresh", async () => {
    createServerClient.mockImplementation((_url, _key, options) => ({
      auth: {
        getClaims: async () => {
          await options.cookies.setAll(
            [
              {
                name: "sb-demo-auth-token",
                value: "cleared-or-rotated",
                options: { path: "/" },
              },
            ],
            {
              "Cache-Control":
                "private, no-cache, no-store, must-revalidate, max-age=0",
              Expires: "0",
              Pragma: "no-cache",
            },
          );

          throw new Error(
            "claims verification failed: token=secret-value host=db.internal",
          );
        },
      },
    }));

    const { refreshSupabaseSession } = await import("@/lib/supabase/proxy");

    const request = new NextRequest("https://cms.example.com/dashboard", {
      headers: {
        cookie: "existing=value",
      },
    });

    const response = await refreshSupabaseSession(request);

    expect(response).toBeInstanceOf(NextResponse);
    expect(request.cookies.get("sb-demo-auth-token")?.value).toBe(
      "cleared-or-rotated",
    );
    expect(response.cookies.get("sb-demo-auth-token")?.value).toBe(
      "cleared-or-rotated",
    );
    expect(response.headers.get("Cache-Control")).toBe(
      "private, no-cache, no-store, must-revalidate, max-age=0",
    );
    expect(response.headers.get("Expires")).toBe("0");
    expect(response.headers.get("Pragma")).toBe("no-cache");
    expect(JSON.stringify(response)).not.toContain("secret-value");
    expect(JSON.stringify(response)).not.toContain("db.internal");
  });

  it("returns a safe passthrough when getClaims resolves with an error", async () => {
    createServerClient.mockImplementation(() => ({
      auth: {
        getClaims: async () => ({
          data: null,
          error: new Error("invalid JWT signature detail"),
        }),
      },
    }));

    const { refreshSupabaseSession } = await import("@/lib/supabase/proxy");

    const response = await refreshSupabaseSession(
      new NextRequest("https://cms.example.com/dashboard"),
    );

    expect(response).toBeInstanceOf(NextResponse);
    expect(response.cookies.getAll()).toEqual([]);
    expect(JSON.stringify(response)).not.toContain("invalid JWT signature");
  });
});

describe("proxy matcher", () => {
  it("uses a static matcher that excludes asset paths", async () => {
    const { config } = await import("@/proxy");

    expect(config.matcher).toEqual([
      "/((?!_next/static|_next/image|favicon.ico|api/health|api/ready|.*\\.(?:svg|png|jpg|jpeg|gif|webp|ico|css|js|map)$).*)",
    ]);
  });
});
