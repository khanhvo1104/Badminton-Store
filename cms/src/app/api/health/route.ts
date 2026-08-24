import { NextResponse, type NextRequest } from "next/server";

import {
  assertSanitizedHealthPayload,
  buildLivenessBody,
  HEALTH_NO_STORE_HEADERS,
} from "@/lib/ops/health-contract";
import {
  correlationIdFromHeaders,
  writeOperationalLog,
} from "@/lib/ops/operational-log";

export const dynamic = "force-dynamic";
export const runtime = "nodejs";

export async function GET(request: NextRequest) {
  const startedAt = Date.now();
  const body = buildLivenessBody();
  assertSanitizedHealthPayload(body);

  const response = NextResponse.json(body, {
    status: 200,
    headers: HEALTH_NO_STORE_HEADERS,
  });

  writeOperationalLog({
    event: "cms.health.liveness",
    requestId: correlationIdFromHeaders(request.headers),
    route: "/api/health",
    method: "GET",
    status: 200,
    durationMs: Date.now() - startedAt,
    outcome: "ok",
  });

  return response;
}
