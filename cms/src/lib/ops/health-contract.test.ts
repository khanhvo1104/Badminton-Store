import { describe, expect, it, vi } from "vitest";

import {
  assertSanitizedHealthPayload,
  buildLivenessBody,
  buildReadinessBody,
  readinessHttpStatus,
} from "@/lib/ops/health-contract";
import { evaluateReadiness } from "@/lib/ops/readiness";
import { PublicEnvironmentError } from "@/lib/errors/public-environment-error";

describe("health contract", () => {
  it("builds a minimal liveness payload", () => {
    const body = buildLivenessBody();
    expect(body).toEqual({ status: "ok", check: "liveness" });
    expect(() => assertSanitizedHealthPayload(body)).not.toThrow();
  });

  it("maps readiness dependency states to stable statuses", () => {
    expect(buildReadinessBody("ok")).toEqual({
      status: "ok",
      check: "readiness",
      dependency: "supabase",
      dependencyStatus: "ok",
    });
    expect(readinessHttpStatus("ok")).toBe(200);
    expect(readinessHttpStatus("timeout")).toBe(503);
    expect(readinessHttpStatus("misconfigured")).toBe(503);
  });

  it("rejects payloads that leak environment or stack details", () => {
    expect(() =>
      assertSanitizedHealthPayload({
        status: "error",
        detail: "https://abc.supabase.co",
      }),
    ).toThrow(/forbidden/i);

    expect(() =>
      assertSanitizedHealthPayload({
        status: "error",
        stack: "Error\n    at Object.<anonymous> (/Users/me/app/route.ts:1:1)",
      }),
    ).toThrow(/forbidden/i);
  });
});

describe("evaluateReadiness", () => {
  it("reports healthy when the dependency check succeeds", async () => {
    const result = await evaluateReadiness({
      getEnvironment: () => ({
        supabaseUrl: "https://example.supabase.co/",
        supabasePublishableKey: "publishable-key",
      }),
      checkDependency: async () => undefined,
      now: (() => {
        let t = 1000;
        return () => {
          t += 5;
          return t;
        };
      })(),
    });

    expect(result.dependencyStatus).toBe("ok");
    expect(result.durationMs).toBeGreaterThanOrEqual(0);
  });

  it("reports misconfigured without contacting a dependency", async () => {
    const checkDependency = vi.fn();
    const result = await evaluateReadiness({
      getEnvironment: () => {
        throw new PublicEnvironmentError("missing-url");
      },
      checkDependency,
    });

    expect(result.dependencyStatus).toBe("misconfigured");
    expect(checkDependency).not.toHaveBeenCalled();
  });

  it("reports timeout when the dependency exceeds the budget", async () => {
    const result = await evaluateReadiness({
      timeoutMs: 20,
      getEnvironment: () => ({
        supabaseUrl: "https://example.supabase.co/",
        supabasePublishableKey: "publishable-key",
      }),
      checkDependency: async ({ signal }) => {
        await new Promise<void>((_resolve, reject) => {
          const timer = setTimeout(() => {
            reject(new Error("should have aborted"));
          }, 200);
          signal.addEventListener("abort", () => {
            clearTimeout(timer);
            const error = new Error("aborted");
            error.name = "AbortError";
            reject(error);
          });
        });
      },
    });

    expect(result.dependencyStatus).toBe("timeout");
  });

  it("reports unreachable for network failures without leaking messages", async () => {
    const result = await evaluateReadiness({
      getEnvironment: () => ({
        supabaseUrl: "https://example.supabase.co/",
        supabasePublishableKey: "publishable-key",
      }),
      checkDependency: async () => {
        throw new TypeError(
          'fetch failed connecting to postgres://user:secret@db.example/postgres SELECT * FROM "orders"',
        );
      },
    });

    expect(result.dependencyStatus).toBe("unreachable");
    expect(JSON.stringify(result)).not.toMatch(/postgres:\/\//i);
    expect(JSON.stringify(result)).not.toMatch(/secret/);
    expect(JSON.stringify(result)).not.toMatch(/orders/);
  });
});
