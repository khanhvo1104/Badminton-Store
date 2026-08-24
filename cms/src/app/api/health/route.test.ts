import { NextRequest } from "next/server";
import { beforeEach, describe, expect, it, vi } from "vitest";

const writeOperationalLog = vi.hoisted(() => vi.fn());
const evaluateReadiness = vi.hoisted(() => vi.fn());

vi.mock("@/lib/ops/operational-log", async () => {
  const actual = await vi.importActual<
    typeof import("@/lib/ops/operational-log")
  >("@/lib/ops/operational-log");
  return {
    ...actual,
    writeOperationalLog,
  };
});

vi.mock("@/lib/ops/readiness", () => ({
  evaluateReadiness,
}));

describe("GET /api/health", () => {
  beforeEach(() => {
    writeOperationalLog.mockReset();
  });

  it("returns a no-store liveness payload", async () => {
    const { GET } = await import("@/app/api/health/route");
    const response = await GET(
      new NextRequest("http://127.0.0.1/api/health", {
        headers: { "x-request-id": "live-1" },
      }),
    );
    const body = await response.json();

    expect(response.status).toBe(200);
    expect(response.headers.get("cache-control")).toContain("no-store");
    expect(body).toEqual({ status: "ok", check: "liveness" });
    expect(JSON.stringify(body)).not.toMatch(/supabase|password|token|stack/i);
    expect(writeOperationalLog).toHaveBeenCalledWith(
      expect.objectContaining({
        event: "cms.health.liveness",
        route: "/api/health",
        status: 200,
        outcome: "ok",
        requestId: "live-1",
      }),
    );
  });
});

describe("GET /api/ready", () => {
  beforeEach(() => {
    writeOperationalLog.mockReset();
    evaluateReadiness.mockReset();
  });

  it("returns 200 when dependency readiness is ok", async () => {
    evaluateReadiness.mockResolvedValue({
      dependencyStatus: "ok",
      durationMs: 4,
    });

    const { GET } = await import("@/app/api/ready/route");
    const response = await GET(new NextRequest("http://127.0.0.1/api/ready"));
    const body = await response.json();

    expect(response.status).toBe(200);
    expect(body).toEqual({
      status: "ok",
      check: "readiness",
      dependency: "supabase",
      dependencyStatus: "ok",
    });
    expect(JSON.stringify(body)).not.toMatch(
      /publishable|service_role|exception|sql/i,
    );
  });

  it("returns sanitized 503 for misconfigured dependencies", async () => {
    evaluateReadiness.mockResolvedValue({
      dependencyStatus: "misconfigured",
      durationMs: 1,
    });

    const { GET } = await import("@/app/api/ready/route");
    const response = await GET(new NextRequest("http://127.0.0.1/api/ready"));
    const body = await response.json();

    expect(response.status).toBe(503);
    expect(body).toEqual({
      status: "error",
      check: "readiness",
      dependency: "supabase",
      dependencyStatus: "misconfigured",
    });
    expect(writeOperationalLog).toHaveBeenCalledWith(
      expect.objectContaining({
        event: "cms.health.readiness",
        status: 503,
        outcome: "misconfigured",
        errorCode: "misconfigured",
      }),
    );
  });

  it("returns sanitized 503 for timeout and unreachable cases", async () => {
    evaluateReadiness.mockResolvedValue({
      dependencyStatus: "timeout",
      durationMs: 2000,
    });

    const { GET } = await import("@/app/api/ready/route");
    const response = await GET(new NextRequest("http://127.0.0.1/api/ready"));
    const body = await response.json();

    expect(response.status).toBe(503);
    expect(body.dependencyStatus).toBe("timeout");
    expect(JSON.stringify(body)).not.toMatch(/ETIMEDOUT|ECONNREFUSED|stack/i);
  });
});
