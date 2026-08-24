export type OperationalOutcome =
  | "ok"
  | "error"
  | "timeout"
  | "misconfigured"
  | "unreachable";

export type OperationalLogInput = {
  event: string;
  requestId?: string;
  route?: string;
  method?: string;
  status?: number;
  durationMs?: number;
  outcome?: OperationalOutcome;
  errorCode?: string;
};

export type OperationalLogRecord = {
  level: "info" | "warn" | "error";
  event: string;
  requestId?: string;
  route?: string;
  method?: string;
  status?: number;
  durationMs?: number;
  outcome?: OperationalOutcome;
  errorCode?: string;
  ts: string;
};

const ALLOWED_EVENTS = new Set([
  "cms.health.liveness",
  "cms.health.readiness",
  "cms.smoke.check",
]);

const ALLOWED_ERROR_CODES = new Set([
  "misconfigured",
  "timeout",
  "unreachable",
  "unexpected_status",
  "invalid_response",
  "dependency_error",
]);

const ALLOWED_OUTCOMES = new Set<OperationalOutcome>([
  "ok",
  "error",
  "timeout",
  "misconfigured",
  "unreachable",
]);

type LogSink = (line: string) => void;

const SENSITIVE_KEY_PATTERN =
  /authorization|cookie|set-cookie|password|secret|token|apikey|api[_-]?key|service[_-]?role|email|phone|address|database|sql|stack|env/i;

/**
 * Builds a privacy-safe operational log record with allowlisted fields only.
 * Sensitive keys and raw error details are dropped.
 */
export function buildOperationalLogRecord(
  input: OperationalLogInput,
  now: () => Date = () => new Date(),
): OperationalLogRecord | null {
  if (!ALLOWED_EVENTS.has(input.event)) {
    return null;
  }

  const record: OperationalLogRecord = {
    level: resolveLevel(input.outcome),
    event: input.event,
    ts: now().toISOString(),
  };

  if (isSafeRequestId(input.requestId)) {
    record.requestId = input.requestId;
  }

  if (isSafeRoute(input.route)) {
    record.route = input.route;
  }

  if (isSafeMethod(input.method)) {
    record.method = input.method;
  }

  if (typeof input.status === "number" && Number.isInteger(input.status)) {
    record.status = input.status;
  }

  if (
    typeof input.durationMs === "number" &&
    Number.isFinite(input.durationMs) &&
    input.durationMs >= 0
  ) {
    record.durationMs = Math.round(input.durationMs);
  }

  if (input.outcome && ALLOWED_OUTCOMES.has(input.outcome)) {
    record.outcome = input.outcome;
  }

  if (input.errorCode && ALLOWED_ERROR_CODES.has(input.errorCode)) {
    record.errorCode = input.errorCode;
  }

  return record;
}

export function writeOperationalLog(
  input: OperationalLogInput,
  sink: LogSink = defaultSink,
  now: () => Date = () => new Date(),
): OperationalLogRecord | null {
  const record = buildOperationalLogRecord(input, now);
  if (!record) {
    return null;
  }

  const serialized = JSON.stringify(record);
  if (containsForbiddenLogContent(serialized)) {
    sink(
      JSON.stringify({
        level: "error",
        event: input.event,
        outcome: "error",
        errorCode: "invalid_response",
        ts: now().toISOString(),
      }),
    );
    return null;
  }

  sink(serialized);
  return record;
}

export function correlationIdFromHeaders(
  headers: Headers | { get(name: string): string | null },
): string | undefined {
  const incoming =
    headers.get("x-request-id") ?? headers.get("x-correlation-id");
  if (isSafeRequestId(incoming ?? undefined)) {
    return incoming ?? undefined;
  }
  return undefined;
}

export function sanitizeOperationalErrorCode(error: unknown): string {
  if (error && typeof error === "object" && "name" in error) {
    const name = String((error as { name?: unknown }).name ?? "");
    if (name === "TimeoutError" || name === "AbortError") {
      return "timeout";
    }
    if (name === "PublicEnvironmentError") {
      return "misconfigured";
    }
  }

  if (error instanceof TypeError) {
    return "unreachable";
  }

  return "dependency_error";
}

export function containsForbiddenLogContent(value: string): boolean {
  if (SENSITIVE_KEY_PATTERN.test(value)) {
    return true;
  }

  // Block common secret-shaped or PII-shaped payloads that should never appear.
  if (
    /eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]+\./.test(value) ||
    /service_role/i.test(value) ||
    /postgres:\/\//i.test(value) ||
    /-----BEGIN[ A-Z]*PRIVATE KEY-----/.test(value)
  ) {
    return true;
  }

  return false;
}

function resolveLevel(
  outcome: OperationalOutcome | undefined,
): "info" | "warn" | "error" {
  if (!outcome || outcome === "ok") {
    return "info";
  }
  if (outcome === "misconfigured" || outcome === "timeout") {
    return "warn";
  }
  return "error";
}

function isSafeRequestId(value: string | undefined): value is string {
  return (
    typeof value === "string" &&
    value.length > 0 &&
    value.length <= 128 &&
    /^[A-Za-z0-9._:-]+$/.test(value)
  );
}

function isSafeRoute(value: string | undefined): value is string {
  return (
    typeof value === "string" &&
    value.startsWith("/") &&
    value.length <= 64 &&
    /^\/[A-Za-z0-9/_-]*$/.test(value)
  );
}

function isSafeMethod(value: string | undefined): value is string {
  return (
    typeof value === "string" &&
    ["GET", "HEAD", "OPTIONS"].includes(value.toUpperCase())
  );
}

function defaultSink(line: string): void {
  console.info(line);
}
