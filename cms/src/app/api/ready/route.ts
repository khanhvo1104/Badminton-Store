import { NextResponse, type NextRequest } from "next/server";

import {
  assertSanitizedHealthPayload,
  buildReadinessBody,
  HEALTH_NO_STORE_HEADERS,
  readinessHttpStatus,
} from "@/lib/ops/health-contract";
import {
  correlationIdFromHeaders,
  writeOperationalLog,
} from "@/lib/ops/operational-log";
import { evaluateReadiness } from "@/lib/ops/readiness";

export const dynamic = "force-dynamic";
export const runtime = "nodejs";

export async function GET(request: NextRequest) {
  const startedAt = Date.now();
  const evaluation = await evaluateReadiness();
  const body = buildReadinessBody(evaluation.dependencyStatus);
  assertSanitizedHealthPayload(body);

  const status = readinessHttpStatus(evaluation.dependencyStatus);
  const response = NextResponse.json(body, {
    status,
    headers: HEALTH_NO_STORE_HEADERS,
  });

  writeOperationalLog({
    event: "cms.health.readiness",
    requestId: correlationIdFromHeaders(request.headers),
    route: "/api/ready",
    method: "GET",
    status,
    durationMs: Date.now() - startedAt,
    outcome:
      evaluation.dependencyStatus === "ok"
        ? "ok"
        : evaluation.dependencyStatus === "timeout"
          ? "timeout"
          : evaluation.dependencyStatus === "misconfigured"
            ? "misconfigured"
            : evaluation.dependencyStatus === "unreachable"
              ? "unreachable"
              : "error",
    errorCode:
      evaluation.dependencyStatus === "ok"
        ? undefined
        : evaluation.dependencyStatus === "error"
          ? "dependency_error"
          : evaluation.dependencyStatus,
  });

  return response;
}
