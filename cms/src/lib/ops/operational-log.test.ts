import { describe, expect, it, vi } from "vitest";

import {
  buildOperationalLogRecord,
  containsForbiddenLogContent,
  correlationIdFromHeaders,
  sanitizeOperationalErrorCode,
  writeOperationalLog,
} from "@/lib/ops/operational-log";
import { PublicEnvironmentError } from "@/lib/errors/public-environment-error";

describe("operational logging", () => {
  it("emits allowlisted fields only", () => {
    const record = buildOperationalLogRecord({
      event: "cms.health.readiness",
      requestId: "req-123",
      route: "/api/ready",
      method: "GET",
      status: 503,
      durationMs: 12.6,
      outcome: "timeout",
      errorCode: "timeout",
    });

    expect(record).toEqual({
      level: "warn",
      event: "cms.health.readiness",
      requestId: "req-123",
      route: "/api/ready",
      method: "GET",
      status: 503,
      durationMs: 13,
      outcome: "timeout",
      errorCode: "timeout",
      ts: expect.any(String),
    });
  });

  it("drops unknown events and unsafe identifiers", () => {
    expect(
      buildOperationalLogRecord({
        event: "cms.secret.dump",
        requestId: "bad id with spaces",
        route: "https://evil.example/api",
        method: "POST",
        errorCode: "password-leaked",
      }),
    ).toBeNull();
  });

  it("never serializes cookies, auth headers, emails, or raw database errors", () => {
    const lines: string[] = [];
    writeOperationalLog(
      {
        event: "cms.health.liveness",
        requestId: "corr-1",
        route: "/api/health",
        method: "GET",
        status: 200,
        durationMs: 1,
        outcome: "ok",
      },
      (line) => lines.push(line),
    );

    expect(lines).toHaveLength(1);
    expect(lines[0]).not.toMatch(/cookie/i);
    expect(lines[0]).not.toMatch(/authorization/i);
    expect(lines[0]).not.toMatch(/@/);
    expect(lines[0]).not.toMatch(/password/i);
    expect(lines[0]).not.toMatch(/service_role/i);
    expect(lines[0]).not.toMatch(/postgres:\/\//i);
    expect(containsForbiddenLogContent(lines[0]!)).toBe(false);
  });

  it("maps provider failures to allowlisted error codes without leaking details", () => {
    expect(
      sanitizeOperationalErrorCode(new PublicEnvironmentError("missing-url")),
    ).toBe("misconfigured");

    const timeout = new Error(
      'relation "orders" does not exist; password=super-secret',
    );
    timeout.name = "TimeoutError";
    expect(sanitizeOperationalErrorCode(timeout)).toBe("timeout");
    expect(sanitizeOperationalErrorCode(timeout)).not.toContain("orders");
    expect(sanitizeOperationalErrorCode(timeout)).not.toContain("password");

    expect(sanitizeOperationalErrorCode(new TypeError("fetch failed"))).toBe(
      "unreachable",
    );
  });

  it("reads a safe correlation id from request headers", () => {
    const headers = new Headers({
      "x-request-id": "abc-123",
      cookie: "sb-access-token=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.leak.sig",
      authorization: "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.leak.sig",
    });

    expect(correlationIdFromHeaders(headers)).toBe("abc-123");
  });

  it("rejects log payloads that already contain forbidden secret shapes", () => {
    const sink = vi.fn();
    const original = JSON.stringify;

    vi.spyOn(JSON, "stringify").mockImplementationOnce((value) => {
      if (
        value &&
        typeof value === "object" &&
        "event" in (value as object) &&
        (value as { event?: string }).event === "cms.health.liveness"
      ) {
        return '{"event":"cms.health.liveness","authorization":"Bearer secret","ts":"2026-01-01T00:00:00.000Z"}';
      }
      return original(value);
    });

    const result = writeOperationalLog(
      {
        event: "cms.health.liveness",
        route: "/api/health",
        method: "GET",
        status: 200,
        outcome: "ok",
      },
      sink,
    );

    expect(result).toBeNull();
    expect(sink).toHaveBeenCalledTimes(1);
    expect(String(sink.mock.calls[0]?.[0])).not.toContain("Bearer secret");
    expect(String(sink.mock.calls[0]?.[0])).toContain("invalid_response");
    vi.restoreAllMocks();
  });
});
