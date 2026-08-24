// @vitest-environment node
import { describe, expect, it, vi } from "vitest";

import {
  parseSmokeCheckArgs,
  runSmokeCheck,
  sanitizeSmokeMessage,
  validateBaseUrl,
  validateHealthBody,
} from "./lib/smoke-check.mjs";

describe("smoke-check", () => {
  it("requires https unless localhost escape hatch is set", () => {
    expect(() =>
      validateBaseUrl("https://cms.example.com", false).toString(),
    ).not.toThrow();
    expect(() => validateBaseUrl("http://127.0.0.1:3000", false)).toThrow(
      /allow-localhost/i,
    );
    expect(validateBaseUrl("http://127.0.0.1:3000", true).hostname).toBe(
      "127.0.0.1",
    );
    expect(() => validateBaseUrl("http://cms.example.com", true)).toThrow(
      /https/i,
    );
  });

  it("parses bounded timeout and retry flags", () => {
    expect(
      parseSmokeCheckArgs([
        "--base-url",
        "https://cms.example.com",
        "--timeout-ms",
        "2500",
        "--retries",
        "2",
      ]),
    ).toEqual({
      baseUrl: "https://cms.example.com",
      allowLocalhost: false,
      timeoutMs: 2500,
      retries: 2,
    });
  });

  it("passes when liveness and readiness contracts succeed", async () => {
    const fetchImpl = vi.fn(async (url) => {
      const path = String(url);
      if (path.endsWith("/api/health")) {
        return jsonResponse(200, { status: "ok", check: "liveness" });
      }
      return jsonResponse(200, {
        status: "ok",
        check: "readiness",
        dependency: "supabase",
        dependencyStatus: "ok",
      });
    });

    const result = await runSmokeCheck({
      baseUrl: "https://cms.example.com",
      fetchImpl,
      retries: 0,
    });

    expect(result.ok).toBe(true);
    expect(result.exitCode).toBe(0);
    expect(fetchImpl).toHaveBeenCalledTimes(2);
  });

  it("rejects redirects and unexpected content", async () => {
    const redirectResult = await runSmokeCheck({
      baseUrl: "https://cms.example.com",
      retries: 0,
      fetchImpl: async () => {
        throw new TypeError("unexpected redirect");
      },
    });
    expect(redirectResult.ok).toBe(false);
    expect(redirectResult.message).toMatch(/redirect/i);

    const contentResult = await runSmokeCheck({
      baseUrl: "https://cms.example.com",
      retries: 0,
      fetchImpl: async () =>
        new Response("<html>nope</html>", {
          status: 200,
          headers: { "content-type": "text/html" },
        }),
    });
    expect(contentResult.ok).toBe(false);
    expect(contentResult.message).toMatch(/content type/i);
  });

  it("fails closed on readiness dependency errors with sanitized messages", async () => {
    const result = await runSmokeCheck({
      baseUrl: "https://cms.example.com",
      retries: 0,
      fetchImpl: async (url) => {
        if (String(url).endsWith("/api/health")) {
          return jsonResponse(200, { status: "ok", check: "liveness" });
        }
        return jsonResponse(503, {
          status: "error",
          check: "readiness",
          dependency: "supabase",
          dependencyStatus: "timeout",
        });
      },
    });

    expect(result.ok).toBe(false);
    expect(result.exitCode).toBe(1);
    expect(result.message).toBe("Readiness reported dependency failure.");
    expect(result.message).not.toMatch(/password|token|sql/i);
  });

  it("sanitizes operator-facing errors and rejects leaked health bodies", () => {
    expect(
      sanitizeSmokeMessage(
        new Error(
          "connection to postgres://user:s3cret@db/failed for email a@b.com",
        ),
      ),
    ).toBe("Smoke check failed.");

    expect(
      validateHealthBody(
        {
          status: "ok",
          check: "liveness",
          detail: "postgres://user:s3cret@db",
        },
        "liveness",
      ),
    ).toMatch(/forbidden/i);
  });
});

function jsonResponse(status, body) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "content-type": "application/json; charset=utf-8" },
  });
}
