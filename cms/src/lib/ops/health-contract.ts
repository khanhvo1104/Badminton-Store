export type HealthStatus = "ok" | "error";

export type LivenessBody = {
  status: HealthStatus;
  check: "liveness";
};

export type ReadinessCheckState =
  | "ok"
  | "misconfigured"
  | "timeout"
  | "unreachable"
  | "error";

export type ReadinessBody = {
  status: HealthStatus;
  check: "readiness";
  dependency: "supabase";
  dependencyStatus: ReadinessCheckState;
};

export const HEALTH_NO_STORE_HEADERS = {
  "Cache-Control": "no-store, max-age=0",
  "Content-Type": "application/json; charset=utf-8",
} as const;

export const DEFAULT_READINESS_TIMEOUT_MS = 2_000;

export function buildLivenessBody(): LivenessBody {
  return {
    status: "ok",
    check: "liveness",
  };
}

export function buildReadinessBody(
  dependencyStatus: ReadinessCheckState,
): ReadinessBody {
  return {
    status: dependencyStatus === "ok" ? "ok" : "error",
    check: "readiness",
    dependency: "supabase",
    dependencyStatus,
  };
}

export function readinessHttpStatus(
  dependencyStatus: ReadinessCheckState,
): number {
  return dependencyStatus === "ok" ? 200 : 503;
}

export function assertSanitizedHealthPayload(payload: unknown): void {
  const serialized = JSON.stringify(payload);
  const forbidden = [
    /supabase\.co/i,
    /eyJ[A-Za-z0-9_-]{10,}\./,
    /service_role/i,
    /password/i,
    /BEGIN [A-Z ]*PRIVATE KEY/,
    /at\s+\S+\s+\(/,
    /\/Users\//,
    /\/home\//,
    /node_modules/,
    /postgres:\/\//i,
    /SELECT\s+/i,
    /relation\s+"/i,
  ];

  for (const pattern of forbidden) {
    if (pattern.test(serialized)) {
      throw new Error("Health payload contained forbidden content.");
    }
  }
}
