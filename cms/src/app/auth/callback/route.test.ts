import { NextRequest } from "next/server";
import { beforeEach, describe, expect, it, vi } from "vitest";

import { PublicEnvironmentError } from "@/lib/errors/public-environment-error";

const createSupabaseServerClient = vi.hoisted(() => vi.fn());
const getCmsSiteUrl = vi.hoisted(() => vi.fn());

vi.mock("@/lib/supabase/server", () => ({
  createSupabaseServerClient,
}));

vi.mock("@/lib/env/cms-site-url", () => ({
  getCmsSiteUrl,
}));

const VALID_CODE = "34e770dd-9ff9-416c-87fa-43b31d7ef225";

describe("auth callback route", () => {
  beforeEach(() => {
    createSupabaseServerClient.mockReset();
    getCmsSiteUrl.mockReset();
    getCmsSiteUrl.mockReturnValue(new URL("https://cms.example.com"));
  });

  it("exchanges a PKCE code and redirects to the allow-listed next path", async () => {
    const exchangeCodeForSession = vi.fn().mockResolvedValue({
      data: { session: { access_token: "session-token" } },
      error: null,
    });
    createSupabaseServerClient.mockResolvedValue({
      auth: { exchangeCodeForSession },
    });

    const { GET } = await import("@/app/auth/callback/route");
    const response = await GET(
      new NextRequest(
        `https://attacker.example/auth/callback?code=${VALID_CODE}&next=/update-password`,
      ),
    );

    expect(exchangeCodeForSession).toHaveBeenCalledWith(VALID_CODE);
    expect(response.status).toBe(307);
    expect(response.headers.get("location")).toBe(
      "https://cms.example.com/update-password",
    );
    expect(response.headers.get("location")).not.toContain("attacker.example");
    expect(response.headers.get("location")).not.toContain("session-token");
  });

  it("rejects a missing code without exchanging a session", async () => {
    const exchangeCodeForSession = vi.fn();
    createSupabaseServerClient.mockResolvedValue({
      auth: { exchangeCodeForSession },
    });

    const { GET } = await import("@/app/auth/callback/route");
    const response = await GET(
      new NextRequest(
        "https://cms.example.com/auth/callback?next=/update-password",
      ),
    );

    expect(exchangeCodeForSession).not.toHaveBeenCalled();
    expect(response.headers.get("location")).toBe(
      "https://cms.example.com/login?status=recovery-failed",
    );
  });

  it("rejects an invalid code and does not reflect provider errors", async () => {
    const exchangeCodeForSession = vi.fn().mockResolvedValue({
      data: { session: null },
      error: new Error("Invalid PKCE code verifier leaked"),
    });
    createSupabaseServerClient.mockResolvedValue({
      auth: { exchangeCodeForSession },
    });

    const { GET } = await import("@/app/auth/callback/route");
    const response = await GET(
      new NextRequest(
        `https://cms.example.com/auth/callback?code=${VALID_CODE}&error_description=bad%20token`,
      ),
    );

    expect(response.headers.get("location")).toBe(
      "https://cms.example.com/login?status=recovery-failed",
    );
    expect(response.headers.get("location")).not.toMatch(
      /token|verifier|error_description/i,
    );
  });

  it("never reflects an external next destination", async () => {
    const exchangeCodeForSession = vi.fn().mockResolvedValue({
      data: { session: { access_token: "session-token" } },
      error: null,
    });
    createSupabaseServerClient.mockResolvedValue({
      auth: { exchangeCodeForSession },
    });

    const { GET } = await import("@/app/auth/callback/route");
    const response = await GET(
      new NextRequest(
        `https://cms.example.com/auth/callback?code=${VALID_CODE}&next=https://evil.example.com`,
      ),
    );

    expect(response.headers.get("location")).toBe(
      "https://cms.example.com/update-password",
    );
    expect(response.headers.get("location")).not.toContain("evil.example.com");
  });

  it("ignores implicit-grant tokens and other non-code parameters", async () => {
    const exchangeCodeForSession = vi.fn();
    createSupabaseServerClient.mockResolvedValue({
      auth: { exchangeCodeForSession },
    });

    const { GET } = await import("@/app/auth/callback/route");
    const response = await GET(
      new NextRequest(
        "https://cms.example.com/auth/callback?access_token=stolen&refresh_token=stolen&token=stolen&next=/update-password",
      ),
    );

    expect(exchangeCodeForSession).not.toHaveBeenCalled();
    expect(response.headers.get("location")).toBe(
      "https://cms.example.com/login?status=recovery-failed",
    );
    expect(response.headers.get("location")).not.toContain("stolen");
  });

  it("returns a safe configuration failure without falling back to localhost", async () => {
    getCmsSiteUrl.mockImplementation(() => {
      throw new PublicEnvironmentError("missing-url");
    });

    const { GET } = await import("@/app/auth/callback/route");
    const response = await GET(
      new NextRequest(
        `https://cms.example.com/auth/callback?code=${VALID_CODE}`,
      ),
    );

    expect(response.status).toBe(503);
    expect(await response.text()).toBe("Configuration unavailable");
    expect(createSupabaseServerClient).not.toHaveBeenCalled();
  });
});
